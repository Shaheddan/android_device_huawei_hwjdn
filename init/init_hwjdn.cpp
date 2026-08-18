/*
   Copyright (c) 2016, The Linux Foundation. All rights reserved.
   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of The Linux Foundation nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
   THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
   ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
   BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
   OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
   IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define _REALLY_INCLUDE_SYS__SYSTEM_PROPERTIES_H_
#include <sys/_system_properties.h>

#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android-base/strings.h>
#include <iostream>
#include <fstream>
#include <string>

#include "vendor_init.h"
#include "property_service.h"

using android::base::GetProperty;
using namespace std;

typedef struct {
    string model;
    string description;
    string fingerprint;
    string default_network;
    bool is_cdma;
} match_t;

// copied from build/tools/releasetools/ota_from_target_files.py
// but with "." at the end and empty entry
std::vector<std::string> ro_product_props_default_source_order = {
    ".",
    "product.",
    "product_services.",
    "odm.",
    "vendor.",
    "system.",
};

void property_override(char const prop[], char const value[], bool add = true)
{
    auto pi = (prop_info *) __system_property_find(prop);

    if (pi != nullptr)
        __system_property_update(pi, value, strlen(value));
    else if (add) {
        __system_property_add(prop, strlen(prop), value, strlen(value));
    }
}

static match_t matches[] = {
    /* MediaPad T2 8.0 Pro / Honor Pad 2, LTE -- the unit this port was
       developed on. The fingerprint was read off this device's own stock
       EMUI in Phase 0. The description is derived from it by the standard
       "<product>-<type> <version> <id> <incremental> <tags>" convention.
       default_network 9 = LTE/GSM/WCDMA, matching kiwi's L-series entries. */
    {
        "JDN-L01",
        "JDN-user 6.0.1 HuaweiMediaPad JDN-L01C199B003 release-keys",
        "Huawei/JDN/hwjdn:6.0.1/HuaweiMediaPad/JDN-L01C199B003:user/release-keys",
        "9",
        false
    },
    /* JDN-W09 (wifi-only) and JDN-AL00 (CN) are intentionally not listed:
       no verified fingerprint exists for either, and a fabricated one would
       be worse than none. With the bounds check above fixed, an unlisted
       variant returns early and boots on Android 12's derived fingerprint. */
};

static const int n_matches = sizeof(matches) / sizeof(matches[0]);

static void property_set(const char *key, string value, bool add = true)
{
    /* An empty value written to a write-once ro. property claims the slot and
       makes every later attempt fail with "Read-only property was already
       set" -- which is what killed system_server via
       Build.ensureFingerprintProperty(). Refuse instead of poisoning it. */
    if (value.empty()) {
        LOG(WARNING) << "init_hwjdn: refusing to set " << key
                     << " to an empty value";
        return;
    }

    property_override(key, value.c_str(), add);
}

static bool contains(string str, string substr)
{
    return str.find(substr) != string::npos;
}

void vendor_load_properties()
{
    string platform;
    string model;
    string hwsim;
    match_t *match;

    ifstream app_info("/proc/app_info");
    if (app_info.is_open()) {
        while (getline(app_info, model) && !contains(model, "huawei_fac_product_name")) {
        }
        app_info.close();
    }

    /* Temporary: WARNING rather than INFO so it survives any log-level
       filtering. Drop to INFO once /proc/app_info's format is confirmed. */
    LOG(WARNING) << "init_hwjdn: model line read = '" << model << "'";

    for (match = matches; match - matches < n_matches && !contains(model, match->model); match++) {
    }

    /* The loop above ends either on a match or with match == matches +
       n_matches, one past the end. `match` is a pointer into a static array,
       so it is NEVER null -- the original `if (!match)` could not fire, and
       execution fell through to dereference off-the-end memory. Compare
       against the end of the array instead. */
    if (match - matches >= n_matches) {
        LOG(WARNING) << "init_hwjdn: unknown variant, leaving build props "
                     << "alone so init can derive them: '" << model << "'";
        return;
    }

    const auto set_ro_product_prop = [](const std::string &source,
            const std::string &prop, const std::string &value) {
        auto prop_name = "ro.product." + source + prop;
        property_override(prop_name.c_str(), value.c_str(), false);
    };

    property_set("ro.build.product", "hwjdn");
    property_set("ro.build.description", match->description);
    property_set("ro.build.fingerprint", match->fingerprint);

    for (const auto &source : ro_product_props_default_source_order) {
        set_ro_product_prop(source, "device", "hwjdn");
        set_ro_product_prop(source, "model", match->model);
        set_ro_product_prop(source, "name", match->model);
    }

    // Also write vendor properties to avoid mismatch
    property_set("ro.bootimage.build.fingerprint", match->fingerprint, false);
    property_set("ro.odm.build.fingerprint", match->fingerprint, false);
    property_set("ro.system.build.fingerprint", match->fingerprint, false);
    property_set("ro.vendor.build.fingerprint", match->fingerprint, false);

    if (match->is_cdma) {
        property_set("telephony.lteOnCdmaDevice", "1");
    }

    // Fix single sim variant based on property set by the bootloader
    hwsim = GetProperty("ro.boot.hwsim", "");

    if (hwsim == "single") {
        property_set("ro.telephony.default_network", match->default_network);
    } else {
        property_set("persist.radio.multisim.config", "dsds");
        property_set("ro.telephony.ril.config", "simactivation,sim2gsmonly");
        property_set("ro.telephony.default_network", match->default_network + "," +
                match->default_network);
    }

    // Init a dummy BT MAC address, will be overwritten later
    property_set("ro.boot.btmacaddr", "00:00:00:00:00:00");
}
