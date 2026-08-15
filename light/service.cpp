/*
 * Copyright 2017 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "android.hardware.light@2.0-service.hwjdn"

#include <hidl/HidlTransportSupport.h>
#include <utils/Errors.h>

#include "Light.h"

using android::OK;
using android::status_t;
using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;

using android::hardware::light::V2_0::ILight;
using android::hardware::light::V2_0::implementation::Light;

/*
 * This node accepts values but drives nothing on stock firmware -- the kernel
 * in this ROM carries a patch (mdss_dsi.c / mdss_dsi_panel.c) that ties it to
 * the panel's three backlight enable GPIOs. Without that patch the screen
 * cannot be dimmed or blanked.
 */
const static std::string kBacklightPath = "/sys/class/leds/lcd-backlight/brightness";

int main() {
    std::ofstream backlight(kBacklightPath);
    if (!backlight) {
        int error = errno;
        ALOGE("Failed to open %s (%d): %s", kBacklightPath.c_str(), error, strerror(error));
        return -error;
    }

    android::sp<ILight> service = new Light(std::move(backlight));

    configureRpcThreadpool(1, true);

    status_t status = service->registerAsService();
    if (status != OK) {
        ALOGE("Cannot register Light HAL service");
        return 1;
    }

    ALOGI("Light HAL Ready.");
    joinRpcThreadpool();

    ALOGE("Light HAL failed to join thread pool.");
    return 1;
}
