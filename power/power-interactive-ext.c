/*
 * power-interactive-ext.c - hwjdn (MSM8939) screen on/off hook for the qcom
 * power HAL (android.hardware.power-service-qti).
 *
 * Built into the HAL through TARGET_POWERHAL_SET_INTERACTIVE_EXT in
 * BoardConfig.mk; power-common.c's set_interactive() calls
 * power_set_interactive_ext() on every screen-on and on the first screen-off.
 *
 * WHY: core_ctl parks cores (stock: fast cluster cpu0-3 min_cpus 0, efficient
 * cluster cpu4-7 min_cpus 1), and every task's allowed-CPU mask shrinks to the
 * few cores still online. Measured on JDN-L01: system_server, SurfaceFlinger,
 * SystemUI, the launcher and Settings were all confined to cpu5 and cpu7, both
 * busy, while cpu0-3 sat offline, and the UI lagged in most apps. Keeping all
 * eight cores online (min_cpus 4/4) made it smooth. Idle online cores still
 * power-collapse, so the screen-on cost is small; on screen-off the stock
 * parking comes back for standby battery life.
 *
 * Same fix as kiwi (Honor 5X, same SoC) on LineageOS 20, done here through
 * the device hook instead of a patch to the power HAL repository.
 */
#include <stdio.h>
#include <time.h> /* utils.h uses struct timespec without including it */

#include "utils.h"

#define CORE_CTL_FAST_MIN "/sys/devices/system/cpu/cpu0/core_ctl/min_cpus"
#define CORE_CTL_EFFICIENT_MIN "/sys/devices/system/cpu/cpu4/core_ctl/min_cpus"

void power_set_interactive_ext(int on);

static void set_core_ctl_min_cpus(int fast, int efficient) {
    char buf[4];

    snprintf(buf, sizeof(buf), "%d", fast);
    sysfs_write(CORE_CTL_FAST_MIN, buf);
    snprintf(buf, sizeof(buf), "%d", efficient);
    sysfs_write(CORE_CTL_EFFICIENT_MIN, buf);
}

void power_set_interactive_ext(int on) {
    if (on)
        set_core_ctl_min_cpus(4, 4); /* screen on: all eight cores */
    else
        set_core_ctl_min_cpus(0, 1); /* screen off: stock parking */
}
