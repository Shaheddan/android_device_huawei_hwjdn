/*
 * nvtread.c -- combined-transaction i2c block reader, with a watch mode.
 *
 * WHY
 *   Identifying this Novatek part by chip ID failed: the NT36xxx trim
 *   sequence (write 0x35, set page 0x3F004, read 6) returns all zeros, because
 *   0x3F004 is an NT36xxx-era address and this is a 2016 chip. Zeros rather
 *   than timeouts mean the chip is present and driving the bus -- it just does
 *   not implement that protocol.
 *
 *   So stop asking what it is called and ask what it DOES. If the bytes it
 *   returns change when the screen is touched, the packet format can be read
 *   straight off the hardware and the identification problem disappears.
 *
 *   Every read here is a COMBINED write-offset-then-read in one transaction
 *   (ioctl I2C_RDWR, two messages, repeated START). That is what the shell
 *   tools cannot express and why i2cget only ever echoed the last byte written.
 *
 * Usage:
 *   nvtread <dev> <i2c_addr> <offset> <len> [watch]
 *
 *   nvtread /dev/i2c-5 0x01 0x00 16          one read
 *   nvtread /dev/i2c-5 0x01 0x00 16 watch    poll, print only on change
 *
 * In watch mode it runs for about 30 seconds. Touch the screen while it runs:
 * any line after the first means the controller is reporting something.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

/* ABI constants and structs written out rather than pulled from
 * <linux/i2c-dev.h>, which varies across distributions and breaks the
 * cross-build. */
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

#define MAXLEN 128

static int fd;

static int nvt_read(uint16_t addr, uint8_t offset, uint8_t *buf, int len)
{
	uint8_t out = offset;
	struct i2c_msg msgs[2];
	struct i2c_rdwr_ioctl_data pkt;

	msgs[0].addr = addr;
	msgs[0].flags = 0;
	msgs[0].len = 1;
	msgs[0].buf = &out;

	msgs[1].addr = addr;
	msgs[1].flags = I2C_M_RD;
	msgs[1].len = len;
	msgs[1].buf = buf;

	pkt.msgs = msgs;
	pkt.nmsgs = 2;

	return ioctl(fd, I2C_RDWR, &pkt);
}

static void show(const uint8_t *buf, int len, const char *tag)
{
	int i;
	printf("%s ", tag);
	for (i = 0; i < len; i++)
		printf("%02X ", buf[i]);
	printf(" |");
	for (i = 0; i < len; i++)
		printf("%c", (buf[i] >= 32 && buf[i] < 127) ? buf[i] : '.');
	printf("|\n");
	fflush(stdout);
}

int main(int argc, char **argv)
{
	const char *dev;
	uint16_t addr;
	uint8_t offset;
	int len, watch, r;
	uint8_t buf[MAXLEN], prev[MAXLEN];
	int changes = 0;
	time_t start;

	if (argc < 5) {
		fprintf(stderr,
			"usage: %s <dev> <i2c_addr> <offset> <len> [watch]\n"
			"  e.g. %s /dev/i2c-5 0x01 0x00 16 watch\n",
			argv[0], argv[0]);
		return 2;
	}

	dev = argv[1];
	addr = (uint16_t)strtoul(argv[2], NULL, 0);
	offset = (uint8_t)strtoul(argv[3], NULL, 0);
	len = (int)strtoul(argv[4], NULL, 0);
	watch = (argc > 5 && strcmp(argv[5], "watch") == 0);

	if (len < 1 || len > MAXLEN) {
		fprintf(stderr, "len must be 1..%d\n", MAXLEN);
		return 2;
	}

	fd = open(dev, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "open %s: %s\n", dev, strerror(errno));
		return 1;
	}

	printf("%s addr 0x%02X offset 0x%02X len %d%s\n\n",
	       dev, addr, offset, len, watch ? "  (watch mode, ~30 s)" : "");

	r = nvt_read(addr, offset, buf, len);
	if (r < 0) {
		fprintf(stderr, "read failed: %s\n", strerror(errno));
		close(fd);
		return 1;
	}
	show(buf, len, "base:");
	memcpy(prev, buf, len);

	if (!watch) {
		close(fd);
		return 0;
	}

	printf("\nTOUCH THE SCREEN NOW. Lines below mean the data changed.\n\n");
	start = time(NULL);

	while (time(NULL) - start < 30) {
		r = nvt_read(addr, offset, buf, len);
		if (r >= 0 && memcmp(buf, prev, len) != 0) {
			show(buf, len, "     ");
			memcpy(prev, buf, len);
			changes++;
		}
		usleep(20000);	/* 50 Hz -- fast enough to catch a tap */
	}

	printf("\n%d change%s in 30 s.\n", changes, changes == 1 ? "" : "s");
	if (!changes)
		printf("No change: this address/offset does not carry touch data,\n"
		       "or the controller is not reporting.\n");

	close(fd);
	return 0;
}
