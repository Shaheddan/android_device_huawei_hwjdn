package org.lineageos.settings.jdn;

import android.view.animation.AlphaAnimation;
import android.view.animation.AnimationSet;
import android.view.animation.LayoutAnimationController;
import android.view.animation.TranslateAnimation;

import androidx.recyclerview.widget.RecyclerView;
import androidx.recyclerview.widget.SimpleItemAnimator;

/** List setup shared by the JdnParts pages. */
final class JdnPage {

    private JdnPage() {}

    /**
     * @param entrance play the page entrance: the cards rise into place one after another
     *                 (only when the page opens, not when it is recreated on rotation)
     */
    static void setUpList(RecyclerView list, boolean entrance) {
        // Status and card updates rebind the same row in place, so their own animations
        // (colour blends, count-ups, cross-fades) run instead of the list's cross-fade
        // between two copies of the row. Rows appearing or leaving still animate.
        if (list.getItemAnimator() instanceof SimpleItemAnimator) {
            ((SimpleItemAnimator) list.getItemAnimator()).setSupportsChangeAnimations(false);
        }
        if (!entrance || !JdnMotion.enabled()) return;
        final AnimationSet rise = new AnimationSet(true);
        rise.addAnimation(new AlphaAnimation(0f, 1f));
        rise.addAnimation(new TranslateAnimation(0f, 0f, JdnStyle.dp(list.getContext(), 32), 0f));
        rise.setDuration(JdnMotion.LONG);
        rise.setInterpolator(JdnMotion.EMPHASIZED_DECELERATE);
        final LayoutAnimationController controller = new LayoutAnimationController(rise, 0.12f);
        list.setLayoutAnimation(controller);
    }
}
