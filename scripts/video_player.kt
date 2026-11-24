package com.webtoapp.template

import android.app.PictureInPictureParams
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Rational
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView

/**
 * Media3 local video player for completed downloads.
 * The PlayerView controller supplies seek, pause/play and position display.
 * No DRM bypass or guaranteed codec support is implied.
 */
class VideoPlayerActivity : AppCompatActivity() {
 private lateinit var player: ExoPlayer
 private lateinit var videoView: PlayerView
 private lateinit var controls: LinearLayout
 private var pip = false
 private var captions = true
 private var fill = false
 private val speeds = floatArrayOf(0.75f,1.0f,1.25f,1.5f,2.0f)
 private var speedIndex = 1
 private fun Int.dp()=(this * resources.displayMetrics.density).toInt()
 private fun action(label:String,click:()->Unit)=TextView(this).apply{
  text=label;textSize=13f;gravity=Gravity.CENTER
  setTextColor(0xff00E5EE.toInt())
  setPadding(11.dp(),10.dp(),11.dp(),10.dp())
  setOnClickListener{click()}
 }
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  val uri:Uri=intent.data?:run{finish();return}
  window.setBackgroundDrawableResource(android.R.color.black)
  window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
  player=ExoPlayer.Builder(this).build()
  player.addListener(object:Player.Listener{
   override fun onPlayerError(error:PlaybackException){
    Toast.makeText(this@VideoPlayerActivity,
     "Unable to play this file: "+(error.message?:"unsupported media"),Toast.LENGTH_LONG).show()
   }
  })
  val root=FrameLayout(this).apply{setBackgroundColor(Color.BLACK)}
  videoView=PlayerView(this).apply{
   player=this@VideoPlayerActivity.player
   useController=true
   controllerShowTimeoutMs=5000
   setBackgroundColor(Color.BLACK)
   resizeMode=AspectRatioFrameLayout.RESIZE_MODE_FIT
  }
  root.addView(videoView,FrameLayout.LayoutParams(-1,-1,Gravity.CENTER))
  controls=LinearLayout(this).apply{
   orientation=LinearLayout.HORIZONTAL
   gravity=Gravity.CENTER_VERTICAL
   setPadding(6.dp(),4.dp(),6.dp(),4.dp())
   setBackgroundColor(0xee091316.toInt())
  }
  controls.addView(action("‹ Back"){finish()},LinearLayout.LayoutParams(0,-2,1f))
  controls.addView(action("1.0×"){
   speedIndex=(speedIndex+1)%speeds.size
   player.setPlaybackSpeed(speeds[speedIndex])
   (controls.getChildAt(1) as TextView).text=speeds[speedIndex].toString()+"×"
   videoView.showController()
  })
  controls.addView(action("CC"){
   captions=!captions
   player.trackSelectionParameters=player.trackSelectionParameters.buildUpon()
    .setTrackTypeDisabled(C.TRACK_TYPE_TEXT,!captions).build()
   (controls.getChildAt(2) as TextView).alpha=if(captions)1f else 0.4f
  })
  controls.addView(action("Fit"){
   fill=!fill
   videoView.resizeMode=if(fill)AspectRatioFrameLayout.RESIZE_MODE_ZOOM
    else AspectRatioFrameLayout.RESIZE_MODE_FIT
   (controls.getChildAt(3) as TextView).text=if(fill)"Fill" else "Fit"
  })
  controls.addView(action("Rotate"){
   requestedOrientation=if(resources.configuration.orientation==Configuration.ORIENTATION_LANDSCAPE)
    ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
  })
  if(Build.VERSION.SDK_INT>=26){
   controls.addView(action("PiP"){enterPip()})
  }
  root.addView(controls,FrameLayout.LayoutParams(-1,-2,Gravity.TOP))
  setContentView(root)
  player.setMediaItem(MediaItem.fromUri(uri))
  player.prepare()
  player.playWhenReady=true
 }
 private fun enterPip(){
  if(Build.VERSION.SDK_INT>=26 && player.isPlaying){
   try{
    enterPictureInPictureMode(PictureInPictureParams.Builder()
     .setAspectRatio(Rational(16,9)).build())
   }catch(_:Exception){
    Toast.makeText(this,"Picture-in-picture unavailable",Toast.LENGTH_SHORT).show()
   }
  }
 }
 override fun onPictureInPictureModeChanged(isInPictureInPictureMode:Boolean,newConfig:Configuration){
  super.onPictureInPictureModeChanged(isInPictureInPictureMode,newConfig)
  pip=isInPictureInPictureMode
  controls.visibility=if(pip)View.GONE else View.VISIBLE
  videoView.useController=!pip
 }
 override fun onPause(){
  super.onPause()
  if(!pip && ::player.isInitialized && !isChangingConfigurations)player.pause()
 }
 override fun onDestroy(){
  if(::videoView.isInitialized)videoView.player=null
  if(::player.isInitialized)player.release()
  super.onDestroy()
 }
}
