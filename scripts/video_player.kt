package com.webtoapp.template

import android.app.PictureInPictureParams
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Rational
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.TextView
import android.widget.Toast
import android.widget.VideoView
import androidx.appcompat.app.AppCompatActivity

/**
 * Native playback for completed local videos only.
 * Uses Android's available codecs (does not bypass DRM or support every format).
 * MediaController provides scrubbing, seeking and basic play/pause.
 */
class VideoPlayerActivity : AppCompatActivity() {
 private lateinit var video: VideoView
 private lateinit var controls: LinearLayout
 private lateinit var mediaControls: MediaController
 private var player: MediaPlayer? = null
 private val speeds = floatArrayOf(0.75f, 1f, 1.25f, 1.5f, 2f)
 private var speedIndex = 1
 private var pip = false
 private fun Int.dp() = (this * resources.displayMetrics.density).toInt()
 private fun button(text: String, click: () -> Unit): TextView = TextView(this).apply {
  this.text = text
  setTextColor(0xff00E5EE.toInt())
  textSize = 14f
  gravity = Gravity.CENTER
  setPadding(12.dp(), 10.dp(), 12.dp(), 10.dp())
  setOnClickListener { click() }
 }
 override fun onCreate(savedInstanceState: Bundle?) {
  super.onCreate(savedInstanceState)
  window.setBackgroundDrawableResource(android.R.color.black)
  window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
  val source: Uri = intent.data ?: run { finish(); return }
  val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
  video = VideoView(this).apply {
   setOnErrorListener { _, what, extra ->
    Toast.makeText(this@VideoPlayerActivity, "This file cannot be played by the Android video decoder (" + what + ")", Toast.LENGTH_LONG).show()
    false
   }
   setOnPreparedListener { mp ->
    player = mp
    mp.isLooping = false
    setSpeed(1f)
    start()
    showController()
   }
  }
  root.addView(video, FrameLayout.LayoutParams(-1, -1, Gravity.CENTER))
  mediaControls = MediaController(this).apply { setAnchorView(video) }
  video.setMediaController(mediaControls)
  controls = LinearLayout(this).apply {
   orientation = LinearLayout.HORIZONTAL
   gravity = Gravity.CENTER_VERTICAL
   setBackgroundColor(0xee0b1417.toInt())
   setPadding(8.dp(), 6.dp(), 8.dp(), 6.dp())
  }
  controls.addView(button("‹ Back") { finish() }, LinearLayout.LayoutParams(0, -2, 1f))
  controls.addView(button("▶ / Ⅱ") { if(video.isPlaying) video.pause() else video.start(); showController() })
  controls.addView(button("1.0×") {
   speedIndex = (speedIndex + 1) % speeds.size
   setSpeed(speeds[speedIndex])
   (controls.getChildAt(2) as TextView).text = speeds[speedIndex].toString() + "×"
  })
  controls.addView(button("Rotate") {
   requestedOrientation = if(resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE)
    ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
  })
  if(Build.VERSION.SDK_INT >= 26) {
   controls.addView(button("PiP") { enterPip() })
  }
  root.addView(controls, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))
  setContentView(root)
  video.setVideoURI(source)
  video.requestFocus()
 }
 private fun showController() {
  mediaControls.show(4000)
 }
 private fun setSpeed(speed: Float) {
  if(Build.VERSION.SDK_INT >= 23) {
   try { player?.let { mp -> mp.playbackParams = mp.playbackParams.setSpeed(speed) } }
   catch(_: Exception) { Toast.makeText(this, "Playback speed not supported", Toast.LENGTH_SHORT).show() }
  }
 }
 private fun enterPip() {
  if(Build.VERSION.SDK_INT >= 26 && video.isPlaying) {
   try {
    enterPictureInPictureMode(PictureInPictureParams.Builder()
     .setAspectRatio(Rational(16, 9)).build())
   } catch(_: Exception) {
    Toast.makeText(this, "Picture-in-picture is unavailable", Toast.LENGTH_SHORT).show()
   }
  }
 }
 override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
  super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
  pip = isInPictureInPictureMode
  controls.visibility = if(pip) View.GONE else View.VISIBLE
 }
 override fun onPause() {
  super.onPause()
  if(!pip && !isChangingConfigurations) video.pause()
 }
 override fun onDestroy() {
  player = null
  video.stopPlayback()
  super.onDestroy()
 }
}
