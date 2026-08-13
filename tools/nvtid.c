/*
 * nvtid.c -- read the chip ID from a Novatek touch controller.
 *
 * WHY THIS EXISTS
 *   jdn's digitiser answers i2c at 0x01 and 0x62 but returns filler (0xaa
 *   everywhere) to ordinary register reads. That is not a fault: Novatek
 *   parts use a command/offset protocol, and reading the ID needs a COMBINED
 *   write-then-read in a single i2c transaction. i2cget/i2cset use SMBus
 *   semantics and cannot express that, which is why poking registers from the
 *   shell only ever echoed back the last byte written.
 *
 *   Rather than port 85 KB of NT36xxx driver on the guess that it matches,
 *   this reproduces just the identification sequence from
 *   nvt_ts_check_chip_ver_trim() and prints the six ID bytes. Those bytes then
 *   say which Novatek part this actually is, and therefore which driver is
 *   worth porting.
 *
 * THE SEQUENCE, copied from the driver (nt36xxx.c):
 *   nvt_bootloader_reset()  write {0x00,0x69} to 0x62, wait 35 ms
 *   per attempt:
 *     nvt_sw_reset_idle()   write {0x00,0xA5} to 0x62, wait 15 ms
 *                           write {0x00,0x35} to 0x62, wait 10 ms
 *     nvt_set_page()        write {0xFF, addr>>16, addr>>8} to 0x01
 *     CTP_I2C_READ(...,7)   write {addr & 0xFF} then READ 6 bytes, from 0x01
 *   The six bytes read are the chip ID.
 *
 * PREREQUISITES ON THE DEVICE: both power rails must already be high --
 *   gpio 1014 (pin 112, vdd) and gpio 1019 (pin 117, avdd) -- and a reset
 *   pulse on gpio 914 (pin 12) helps. This program does not touch GPIOs.
 *
 * Build:
 *   aarch64-linux-gnu-gcc -static -O2 -o nvtid nvtid.c
 * Run:
 *   ./nvtid /dev/i2c-5 0x3F004
 *   ./nvtid /dev/i2c-5 0x1F64E      (the "old" trim address)
 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

/* Declared here rather than including <linux/i2c-dev.h>, which is missing or
 * inconsistent across distributions and would break the cross-build. These
 * definitions are ABI, not implementation, so writing them out is safe. */
#define I2C_RDWR 0x0707
#define I2C_M_RD 0x0001

struct i2c_msg {
	uint16_t addr;
	uint16_t flags;
	uint16_t len;
	uint8_t *buf;
};

struct i2c_rdwr_ioctl_data {
	struct i2c_msg *msgs;
	int nmsgs;
};

#define BLDR_ADDR 0x01		/* I2C_BLDR_Address / I2C_FW_Address */
#define HW_ADDR   0x62		/* I2C_HW_Address */

static int fd;

static int nvt_write(uint16_t addr, const uint8_t *data, int len)
{
	uint8_t tmp[16];
	struct i2c_msg msg;
	struct i2c_rdwr_ioctl_data pkt;

	if (len > (int)sizeof(tmp))
		return -1;
	memcpy(tmp, data, len);

	msg.addr = addr;
	msg.flags = 0;
	msg.len = len;
	msg.buf = tmp;

	pkt.msgs = &msg;
	pkt.nmsgs = 1;

	return ioctl(fd, I2C_RDWR, &pkt);
}

/* Mirrors CTP_I2C_READ: buf[0] is written as the offset, then len-1 bytes are
 * read back into buf[1..]. Both messages go in ONE ioctl so the controller
 * issues a repeated START rather than a STOP -- that distinction is the whole
 * reason the shell tools could not do this. */
static int nvt_read(uint16_t addr, uint8_t *buf, int len)
{
	uint8_t out = buf[0];
	struct i2c_msg msgs[2];
	struct i2c_rdwr_ioctl_data pkt;

	msgs[0].addr = addr;
	msgs[0].flags = 0;
	msgs[0].len = 1;
	msgs[0].buf = &out;

	msgs[1].addr = addr;
	msgs[1].flags = I2C_M_RD;
	msgs[1].len = len - 1;
	msgs[1].buf = buf + 1;

	pkt.msgs = msgs;
	pkt.nmsgs = 2;

	return ioctl(fd, I2C_RDWR, &pkt);
}

static void ms(int n) { usleep(n * 1000); }

static void bootloader_reset(void)
{
	const uint8_t cmd[2] = { 0x00, 0x69 };
	int r = nvt_write(HW_ADDR, cmd, 2);
	printf("  bootloader_reset  write{00,69}@0x62 -> %s\n",
	       r < 0 ? strerror(errno) : "ok");
	ms(35);
}

static void sw_reset_idle(void)
{
	const uint8_t cmd[2] = { 0x00, 0xA5 };
	nvt_write(HW_ADDR, cmd, 2);
	ms(15);
}

static int set_page(uint16_t addr, uint32_t page)
{
	uint8_t cmd[3];
	cmd[0] = 0xFF;
	cmd[1] = (page >> 16) & 0xFF;
	cmd[2] = (page >> 8) & 0xFF;
	return nvt_write(addr, cmd, 3);
}

int main(int argc, char **argv)
{
	const char *dev = (argc > 1) ? argv[1] : "/dev/i2c-5";
	uint32_t trim = (argc > 2) ? (uint32_t)strtoul(argv[2], NULL, 0) : 0x3F004;
	uint8_t buf[8];
	int attempt, r;

	fd = open(dev, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "open %s: %s\n", dev, strerror(errno));
		return 1;
	}

	printf("device %s, trim address 0x%05X\n\n", dev, trim);
	bootloader_reset();

	for (attempt = 1; attempt <= 5; attempt++) {
		printf("\nattempt %d\n", attempt);

		sw_reset_idle();

		buf[0] = 0x00;
		buf[1] = 0x35;
		nvt_write(HW_ADDR, buf, 2);
		ms(10);

		r = set_page(BLDR_ADDR, trim);
		if (r < 0) {
			printf("  set_page failed: %s\n", strerror(errno));
			continue;
		}

		memset(buf, 0, sizeof(buf));
		buf[0] = trim & 0xFF;
		r = nvt_read(BLDR_ADDR, buf, 7);
		if (r < 0) {
			printf("  read failed: %s\n", strerror(errno));
			ms(10);
			continue;
		}

		printf("  CHIP ID: %02X %02X %02X %02X %02X %02X\n",
		       buf[1], buf[2], buf[3], buf[4], buf[5], buf[6]);

		/* The driver treats these as "not settled yet" and retries after
		 * stopping the CRC reboot; we simply report and keep going. */
		if (buf[1] == 0xFC)
			printf("  (0xFC -> CRC check active; driver would call "
			       "nvt_stop_crc_reboot and retry)\n");
		else if (buf[1] == 0xFF && buf[2] == 0xFF && buf[3] == 0xFF)
			printf("  (all-FF -> chip not responding with real data yet)\n");
		else
			printf("  ^^^ looks like a real ID\n");

		ms(10);
	}

	close(fd);
	return 0;
}
