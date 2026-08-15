/*
 * Copyright (C) 2016 The Android Open Source Project
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "light"

#include "Light.h"

#include <log/log.h>

#include <fstream>

namespace {

using android::hardware::light::V2_0::LightState;

/*
 * This device has RED and GREEN emitters only. The `blue` sysfs node exists
 * but drives nothing -- verified by writing 255 to it on the hardware.
 */
constexpr const char kRed[] = "/sys/class/leds/red/";
constexpr const char kGreen[] = "/sys/class/leds/green/";

static void write(const std::string& path, const std::string& value) {
    std::ofstream out(path);
    if (!out) {
        ALOGW("failed to open %s", path.c_str());
        return;
    }
    out << value << std::endl;
}

static bool exists(const std::string& path) {
    std::ifstream in(path);
    return in.good();
}

static uint32_t rgbToBrightness(const LightState& state) {
    uint32_t color = state.color & 0x00ffffff;
    return ((77 * ((color >> 16) & 0xff)) + (150 * ((color >> 8) & 0xff)) +
            (29 * (color & 0xff))) >> 8;
}

static bool isLit(const LightState& state) {
    return (state.color & 0x00ffffff);
}

}  // anonymous namespace

namespace android {
namespace hardware {
namespace light {
namespace V2_0 {
namespace implementation {

Light::Light(std::ofstream&& backlight) : mBacklight(std::move(backlight)) {
    auto attnFn(std::bind(&Light::setAttentionLight, this, std::placeholders::_1));
    auto backlightFn(std::bind(&Light::setBacklight, this, std::placeholders::_1));
    auto batteryFn(std::bind(&Light::setBatteryLight, this, std::placeholders::_1));
    auto notifFn(std::bind(&Light::setNotificationLight, this, std::placeholders::_1));
    mLights.emplace(std::make_pair(Type::ATTENTION, attnFn));
    mLights.emplace(std::make_pair(Type::BACKLIGHT, backlightFn));
    mLights.emplace(std::make_pair(Type::BATTERY, batteryFn));
    mLights.emplace(std::make_pair(Type::NOTIFICATIONS, notifFn));

    mBlinkSupported = exists(std::string(kRed) + "delay_on");
    ALOGI("hardware blink %s", mBlinkSupported ? "available" : "unavailable (solid only)");
}

Return<Status> Light::setLight(Type type, const LightState& state) {
    auto it = mLights.find(type);
    if (it == mLights.end()) {
        return Status::LIGHT_NOT_SUPPORTED;
    }
    it->second(state);
    return Status::SUCCESS;
}

Return<void> Light::getSupportedTypes(getSupportedTypes_cb _hidl_cb) {
    std::vector<Type> types;
    for (auto const& light : mLights) {
        types.push_back(light.first);
    }
    _hidl_cb(types);
    return Void();
}

void Light::setAttentionLight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    mAttentionState = state;
    setSpeakerBatteryLightLocked();
}

void Light::setBacklight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    mBacklight << rgbToBrightness(state) << std::endl;
}

void Light::setBatteryLight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    mBatteryState = state;
    setSpeakerBatteryLightLocked();
}

void Light::setNotificationLight(const LightState& state) {
    std::lock_guard<std::mutex> lock(mLock);
    mNotificationState = state;
    setSpeakerBatteryLightLocked();
}

void Light::setSpeakerBatteryLightLocked() {
    if (isLit(mNotificationState)) {
        setSpeakerLightLocked(mNotificationState);
    } else if (isLit(mAttentionState)) {
        setSpeakerLightLocked(mAttentionState);
    } else {
        setSpeakerLightLocked(mBatteryState);
    }
}

void Light::setSpeakerLightLocked(const LightState& state) {
    uint32_t red = (state.color >> 16) & 0xff;
    uint32_t green = (state.color >> 8) & 0xff;
    uint32_t blue = state.color & 0xff;

    /*
     * There is no blue emitter. Folding blue into green means a blue-only
     * notification still shows something rather than appearing broken; the
     * colour is wrong, but silence would be worse. Drop this line if you would
     * rather blue-only notifications stay dark.
     */
    if (green < blue) {
        green = blue;
    }

    bool blink = state.flashMode == Flash::TIMED && state.flashOnMs > 0 &&
                 state.flashOffMs > 0 && mBlinkSupported;

    if (blink) {
        /*
         * Order matters: selecting the trigger creates delay_on/delay_off and
         * resets brightness, so the timings and the level must be written
         * after it.
         */
        for (auto led : {kRed, kGreen}) {
            write(std::string(led) + "trigger", "timer");
            write(std::string(led) + "delay_on", std::to_string(state.flashOnMs));
            write(std::string(led) + "delay_off", std::to_string(state.flashOffMs));
        }
    } else {
        for (auto led : {kRed, kGreen}) {
            write(std::string(led) + "trigger", "none");
        }
    }

    write(std::string(kRed) + "brightness", std::to_string(red));
    write(std::string(kGreen) + "brightness", std::to_string(green));
}

}  // namespace implementation
}  // namespace V2_0
}  // namespace light
}  // namespace hardware
}  // namespace android
