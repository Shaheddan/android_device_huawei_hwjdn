/*
 * Copyright (C) 2016 The Android Open Source Project
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef ANDROID_HARDWARE_LIGHT_V2_0_LIGHT_H
#define ANDROID_HARDWARE_LIGHT_V2_0_LIGHT_H

#include <android/hardware/light/2.0/ILight.h>
#include <hidl/Status.h>

#include <fstream>
#include <mutex>
#include <string>
#include <unordered_map>

namespace android {
namespace hardware {
namespace light {
namespace V2_0 {
namespace implementation {

struct Light : public ILight {
    Light(std::ofstream&& backlight);

    // Methods from ::android::hardware::light::V2_0::ILight follow.
    Return<Status> setLight(Type type, const LightState& state) override;
    Return<void> getSupportedTypes(getSupportedTypes_cb _hidl_cb) override;

  private:
    void setAttentionLight(const LightState& state);
    void setBacklight(const LightState& state);
    void setBatteryLight(const LightState& state);
    void setNotificationLight(const LightState& state);
    void setSpeakerBatteryLightLocked();
    void setSpeakerLightLocked(const LightState& state);

    std::ofstream mBacklight;

    LightState mAttentionState;
    LightState mBatteryState;
    LightState mNotificationState;

    /*
     * Probed once in the constructor rather than assumed: the kernel this
     * device currently ships has no `timer` LED trigger, so delay_on does not
     * exist and the LED can only be solid. A later kernel with
     * CONFIG_LEDS_TRIGGER_TIMER makes blinking work with no change here.
     */
    bool mBlinkSupported;

    std::unordered_map<Type, std::function<void(const LightState&)>> mLights;
    std::mutex mLock;
};

}  // namespace implementation
}  // namespace V2_0
}  // namespace light
}  // namespace hardware
}  // namespace android

#endif  // ANDROID_HARDWARE_LIGHT_V2_0_LIGHT_H
