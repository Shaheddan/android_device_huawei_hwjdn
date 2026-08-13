#!/usr/bin/env python3
"""
patch_backlight.py -- make /sys/class/leds/lcd-backlight/brightness actually
                      control jdn's backlight.

THE PROBLEM
    jdn's panel declares qcom,mdss-dsi-bl-pmic-control-type = "bl_ctrl_dcs", so
    the kernel sends brightness as DSI commands to the panel controller. The
    physical backlight, though, hangs off three GPIOs that no CAF property name
    covers -- Huawei named them after the schematic net rather than the pin:

        qcom,platform-vcc-gpio2     pin 2    -> sysfs 904
        qcom,platform-bl-gpio109    pin 3    -> sysfs 905   the backlight enable
        qcom,platform-vled-gpio97   pin 109  -> sysfs 1011

    A grep for those names across drivers/video/ finds nothing, so nothing in
    the kernel drives them. That is why writing 255 to the brightness node
    holds the value and lights nothing, and why TWRP can blank the screen but
    never un-blank it.

WHAT THIS PATCH DOES
    1. mdss_dsi.h   -- three new fields on the ctrl struct.
    2. mdss_dsi.c   -- parse the three properties and request all three HIGH,
                       right after the existing bklight-en-gpio parsing. High
                       at request time means the display keeps working from
                       boot exactly as it does now.
    3. mdss_dsi_panel.c -- in mdss_dsi_panel_bl_ctrl(), drive the bl pin from
                       the brightness level: 0 turns it off, anything else on.

    ONLY the bl pin is toggled. vcc is likely panel power rather than
    backlight, and cutting it while the panel is running is a risk with nothing
    to gain -- dropping bl alone was verified sufficient on the hardware.

    New fields are used rather than the existing disp_en_gpio / bklt_en_gpio
    because mdss_dsi_panel_reset() gpio_free()s those on panel disable, which
    would leave the pins unowned exactly when we need them.

Usage:
    python3 patch_backlight.py [path-to-kernel-tree]

Idempotent: re-running detects the sentinel and does nothing.
"""

import os
import sys

KERNEL = sys.argv[1] if len(sys.argv) > 1 else \
    os.path.expanduser("~/android/references/kiwi-kernel")
MDSS = os.path.join(KERNEL, "drivers/video/msm/mdss")

SENTINEL = "hw_bl_gpio"


def check(filename, anchor, label):
    """Validate one anchor without writing anything.

    Returns "done" if already patched, "ready" if the anchor is present
    exactly once, or exits on anything else.

    The guard tests for SENTINEL rather than for part of the addition,
    because the addition is inserted AFTER the anchor -- testing the
    addition's own first line would match the anchor on a pristine file and
    silently report 'already patched'. That bug skipped every patch once.
    """
    path = os.path.join(MDSS, filename)
    if not os.path.isfile(path):
        print(f"  {label:<28} FILE NOT FOUND: {path}")
        sys.exit(1)

    src = open(path).read()
    if SENTINEL in src:
        print(f"  {label:<28} already patched")
        return "done"

    n = src.count(anchor)
    if n != 1:
        print(f"  {label:<28} anchor found {n} times, need exactly 1")
        print(f"      looked for: {anchor!r}")
        sys.exit(1)

    print(f"  {label:<28} ready")
    return "ready"


def apply(filename, anchor, addition):
    """Insert `addition` immediately after `anchor`. Only called once every
    anchor in the set has been validated, so the tree is never left half
    patched -- which matters because this kernel currently boots and works."""
    path = os.path.join(MDSS, filename)
    src = open(path).read()
    open(path, "w").write(src.replace(anchor, anchor + addition, 1))


# ---------------------------------------------------------------- 1. header
H_ANCHOR = "\tint bklt_en_gpio;"
H_ADD = """
\t/* Huawei jdn names its backlight enables differently from CAF, so the
\t * stock parsing never finds them. Separate fields rather than reusing
\t * disp_en_gpio/bklt_en_gpio, which mdss_dsi_panel_reset() gpio_free()s
\t * on panel disable -- exactly when we still need to own these. */
\tint hw_vcc_gpio;
\tint hw_bl_gpio;
\tint hw_vled_gpio;"""

# ------------------------------------------------------------------ 2. parse
C_ANCHOR = '\t\t"qcom,platform-bklight-en-gpio", 0);'
C_ADD = """

\t/*
\t * jdn's backlight sits on three GPIOs that no CAF property name covers.
\t * All three must be high for the panel to be lit -- verified live over
\t * adb, where dropping any one of them darkens the screen. Huawei names
\t * them after the schematic net, not the pin: vcc-gpio2 is pin 2,
\t * bl-gpio109 is pin 3, vled-gpio97 is pin 109.
\t *
\t * Requested HIGH so the display behaves from boot exactly as it does
\t * today; only the bl pin is toggled afterwards, by bl_ctrl.
\t */
\tctrl_pdata->hw_vcc_gpio = of_get_named_gpio(ctrl_pdev->dev.of_node,
\t\t"qcom,platform-vcc-gpio2", 0);
\tctrl_pdata->hw_bl_gpio = of_get_named_gpio(ctrl_pdev->dev.of_node,
\t\t"qcom,platform-bl-gpio109", 0);
\tctrl_pdata->hw_vled_gpio = of_get_named_gpio(ctrl_pdev->dev.of_node,
\t\t"qcom,platform-vled-gpio97", 0);

\tif (gpio_is_valid(ctrl_pdata->hw_vcc_gpio))
\t\tgpio_request_one(ctrl_pdata->hw_vcc_gpio,
\t\t\tGPIOF_OUT_INIT_HIGH, "hw_vcc");
\tif (gpio_is_valid(ctrl_pdata->hw_bl_gpio))
\t\tgpio_request_one(ctrl_pdata->hw_bl_gpio,
\t\t\tGPIOF_OUT_INIT_HIGH, "hw_bl");
\tif (gpio_is_valid(ctrl_pdata->hw_vled_gpio))
\t\tgpio_request_one(ctrl_pdata->hw_vled_gpio,
\t\t\tGPIOF_OUT_INIT_HIGH, "hw_vled");

\tpr_info("%s: jdn backlight gpios vcc=%d bl=%d vled=%d\\n", __func__,
\t\tctrl_pdata->hw_vcc_gpio, ctrl_pdata->hw_bl_gpio,
\t\tctrl_pdata->hw_vled_gpio);"""

# ------------------------------------------------------------- 3. brightness
P_ANCHOR = ("\tif ((bl_level < pdata->panel_info.bl_min) && (bl_level != 0))\n"
            "\t\tbl_level = pdata->panel_info.bl_min;")
P_ADD = """

\t/*
\t * The panel is declared bl_ctrl_dcs, so the brightness below goes out as
\t * DSI commands and never reaches the physical backlight. Gate the
\t * hardware enable here so level 0 genuinely turns the light off, which is
\t * what lets the power button blank the screen. Only the bl pin is
\t * touched; see the request site in mdss_dsi.c for why.
\t */
\tif (gpio_is_valid(ctrl_pdata->hw_bl_gpio))
\t\tgpio_set_value(ctrl_pdata->hw_bl_gpio, bl_level ? 1 : 0);"""


def main():
    if not os.path.isdir(MDSS):
        sys.exit(f"ERROR: {MDSS} does not exist")

    jobs = [
        ("mdss_dsi.h",       H_ANCHOR, H_ADD, "mdss_dsi.h struct"),
        ("mdss_dsi.c",       C_ANCHOR, C_ADD, "mdss_dsi.c parsing"),
        ("mdss_dsi_panel.c", P_ANCHOR, P_ADD, "mdss_dsi_panel.c bl_ctrl"),
    ]

    # PHASE 1 -- validate everything before touching anything.
    print(f"checking {MDSS}\n")
    states = [check(f, a, lbl) for f, a, _, lbl in jobs]

    # PHASE 2 -- all anchors good, so apply.
    print()
    n = 0
    for (f, a, add, lbl), st in zip(jobs, states):
        if st == "ready":
            apply(f, a, add)
            print(f"  {lbl:<28} patched")
            n += 1

    print(f"\n{n} file(s) changed")
    print("\nverification:")
    ok = True
    for f in ("mdss_dsi.h", "mdss_dsi.c", "mdss_dsi_panel.c"):
        src = open(os.path.join(MDSS, f)).read()
        hits = src.count(SENTINEL)
        print(f"  {f:<22} {hits} reference(s) to {SENTINEL}")
        if hits == 0:
            ok = False
    print("\n" + ("ALL THREE PATCHED" if ok else "SOMETHING IS MISSING"))


if __name__ == "__main__":
    main()
