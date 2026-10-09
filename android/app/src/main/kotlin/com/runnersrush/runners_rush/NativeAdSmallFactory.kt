package com.runnersrush.runners_rush

import android.graphics.Outline
import android.view.LayoutInflater
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/** Arrow Drift–style small native: no media; full-width CTA at bottom. */
class NativeAdSmallFactory(
    private val layoutInflater: LayoutInflater,
) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?,
    ): NativeAdView {
        val adView = layoutInflater.inflate(
            R.layout.native_ad_small,
            null,
            false,
        ) as NativeAdView

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
            ?: error("native_ad_small missing R.id.ad_headline")
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
            ?: error("native_ad_small missing R.id.ad_body")
        val ctaView = adView.findViewById<TextView>(R.id.ad_call_to_action)
            ?: error("native_ad_small missing R.id.ad_call_to_action")
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
            ?: error("native_ad_small missing R.id.ad_app_icon")
        val starsView = adView.findViewById<RatingBar>(R.id.ad_stars)
            ?: error("native_ad_small missing R.id.ad_stars")
        // Static "Ad" badge — not bound to NativeAd APIs.
        adView.findViewById<TextView>(R.id.ad_attribution)
            ?: error("native_ad_small missing R.id.ad_attribution")

        adView.headlineView = headlineView
        adView.bodyView = bodyView
        adView.callToActionView = ctaView
        adView.iconView = iconView
        adView.starRatingView = starsView

        headlineView.text = nativeAd.headline ?: ""
        headlineView.visibility =
            if (nativeAd.headline.isNullOrEmpty()) View.GONE else View.VISIBLE

        if (nativeAd.body.isNullOrEmpty()) {
            bodyView.visibility = View.GONE
            bodyView.text = ""
        } else {
            bodyView.visibility = View.VISIBLE
            bodyView.text = nativeAd.body
        }

        // GONE (not INVISIBLE) so an empty CTA does not leave a blank strip.
        if (nativeAd.callToAction.isNullOrEmpty()) {
            ctaView.visibility = View.GONE
            ctaView.text = ""
        } else {
            ctaView.visibility = View.VISIBLE
            ctaView.text = nativeAd.callToAction
        }

        val icon = nativeAd.icon
        if (icon == null) {
            iconView.visibility = View.GONE
            iconView.setImageDrawable(null)
        } else {
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
            val radius = 10f * iconView.resources.displayMetrics.density
            iconView.outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setRoundRect(0, 0, view.width, view.height, radius)
                }
            }
            iconView.clipToOutline = true
        }

        val rating = nativeAd.starRating
        if (rating == null || rating <= 0) {
            starsView.visibility = View.GONE
        } else {
            starsView.rating = rating.toFloat()
            starsView.visibility = View.VISIBLE
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
