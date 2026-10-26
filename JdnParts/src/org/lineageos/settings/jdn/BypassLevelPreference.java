package org.lineageos.settings.jdn;

import android.content.Context;
import android.graphics.drawable.ClipDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.InsetDrawable;
import android.graphics.drawable.LayerDrawable;
import android.util.AttributeSet;
import android.view.Gravity;
import android.widget.SeekBar;

import androidx.preference.PreferenceViewHolder;
import androidx.preference.SeekBarPreference;

/**
 * The auto-bypass level as the last row of the mode group, with a Material 3 Expressive
 * style slider: a thick rounded track and a slim vertical handle with a gap around it.
 * Still an androidx SeekBarPreference, so key, range and storage are unchanged.
 */
public class BypassLevelPreference extends SeekBarPreference {

    private int mGroupPosition = JdnStyle.GROUP_BOTTOM;

    public BypassLevelPreference(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public void setGroupPosition(int position) {
        if (position != mGroupPosition) {
            mGroupPosition = position;
            notifyChanged();
        }
    }

    @Override
    public void onBindViewHolder(PreferenceViewHolder holder) {
        super.onBindViewHolder(holder);
        final Context c = getContext();
        JdnRows.styleRow(c, holder, mGroupPosition, false);

        final SeekBar seekBar = JdnRows.findSeekBar(holder.itemView);
        if (seekBar == null) return;

        final float radius = JdnStyle.dp(c, 8);
        final GradientDrawable track = new GradientDrawable();
        track.setCornerRadius(radius);
        track.setColor(JdnStyle.secondaryContainer(c));

        final GradientDrawable active = new GradientDrawable();
        active.setCornerRadius(radius);
        active.setColor(JdnStyle.primary(c));
        final ClipDrawable progress = new ClipDrawable(active, Gravity.START,
                ClipDrawable.HORIZONTAL);

        final LayerDrawable layers = new LayerDrawable(new Drawable[] { track, progress });
        layers.setId(0, android.R.id.background);
        layers.setId(1, android.R.id.progress);
        seekBar.setProgressDrawable(layers);

        final int height = Math.round(JdnStyle.dp(c, 16));
        seekBar.setMinHeight(height);
        seekBar.setMaxHeight(height);

        // Slim handle; the transparent inset is cut out of the track (split track),
        // which gives the expressive gap on both sides of the handle.
        final GradientDrawable handle = new GradientDrawable();
        handle.setCornerRadius(JdnStyle.dp(c, 2));
        handle.setColor(JdnStyle.primary(c));
        handle.setSize(Math.round(JdnStyle.dp(c, 4)), Math.round(JdnStyle.dp(c, 36)));
        final int gap = Math.round(JdnStyle.dp(c, 5));
        seekBar.setThumb(new InsetDrawable(handle, gap, 0, gap, 0));
        seekBar.setSplitTrack(true);
        seekBar.setAlpha(isEnabled() ? 1f : 0.38f);
    }
}
