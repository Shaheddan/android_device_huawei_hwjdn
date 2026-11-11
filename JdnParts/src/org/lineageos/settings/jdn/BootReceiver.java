package org.lineageos.settings.jdn;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Starts BypassService at boot, after resetting the charger to normal charging. The service
 * then stays up and follows plug, unplug and settings changes itself; the power
 * connected/disconnected broadcasts are not delivered to manifest receivers since Android 8.
 *
 * Battery health: the kernel's cycle count is read on every boot. The vm-bms can only clear
 * its count at boot, so reading it on every boot is what lets BatteryHealth keep the total
 * across a reset.
 */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        BypassService.writeNode("1");
        context.startService(new Intent(context, BypassService.class));
        BatteryHealth.update(context, BatteryHealth.stickyBattery(context));
        HealthSummaryProvider.notifyChanged(context);
    }
}
