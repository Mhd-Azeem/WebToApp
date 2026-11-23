import argparse,re,base64
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--url',required=True); p.add_argument('--name',required=True); p.add_argument('--package',required=True)
p.add_argument('--orientation',choices=['auto','portrait','landscape'],default='auto')
p.add_argument('--icon-base64',default='')
# The generated Android UI is authored in the Kotlin template below, not the builder XML.
# Dock expand/collapse state is persisted per installed app.
a=p.parse_args()
root=Path(__file__).resolve().parents[1]/'android-template'; src=root/'app/src/main'
main=src/'java/com/webtoapp/template/MainActivity.kt'; layout=src/'res/layout/activity_main.xml'; manifest=src/'AndroidManifest.xml'; gradle=root/'app/build.gradle.kts'
url=a.url.replace('"',''); name=a.name.replace('"',''); pkg=a.package
orientation={'auto':'unspecified','portrait':'portrait','landscape':'landscape'}[a.orientation]
main.write_text(r'''package com.webtoapp.template
import android.annotation.SuppressLint
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.view.View
import android.view.WindowManager
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.MotionEvent
import android.graphics.drawable.GradientDrawable
import android.os.SystemClock
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import android.database.Cursor
import android.content.ActivityNotFoundException
import android.webkit.*
import android.widget.*
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.OnBackPressedCallback
import java.util.ArrayList
import java.net.HttpURLConnection
import java.net.URL
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.ConcurrentHashMap
import android.content.ContentValues
import android.provider.MediaStore

class MainActivity:AppCompatActivity(){
 private lateinit var container:FrameLayout
 private lateinit var tabButton:TextView
 private lateinit var downloadButton:TextView
 private lateinit var topBar:LinearLayout
 private lateinit var floatingHandle:TextView
 private lateinit var floatingDock:LinearLayout
 private lateinit var currentUrlLabel:TextView
 private lateinit var addressBarView:LinearLayout
 private var chromeVisible=true
 private var chromeAnimator:android.animation.ValueAnimator?=null
 private var dockExpanded=true
 private var controlsExpanded=false
 private val collapseControls=Runnable{setControlsExpanded(false)}
 private val tabs=ArrayList<WebView>()
 private val tabPreviews=java.util.WeakHashMap<WebView,Bitmap>()
 private var offlineOverlay:View?=null
 private var fullscreenCustomView:View?=null
 private var fullscreenCallback:WebChromeClient.CustomViewCallback?=null
 private var active=0
 private val home="__WEB_URL__"
 private val downloads=linkedMapOf<Long,Pair<String,Long>>()
 private data class VideoCandidate(val url:String,val title:String,val mime:String)
 private data class Transfer(val id:Long,val url:String,val filename:String,val mime:String,val agent:String,val cookie:String,val referer:String="",
  @Volatile var state:String="Paused",@Volatile var size:Long=-1,@Volatile var done:Long=0,
  @Volatile var speed:Long=0,@Volatile var stop:Boolean=false,@Volatile var uri:String="")
 private val transfers=ConcurrentHashMap<Long,Transfer>()
 private fun persistTransfer(t:Transfer){
  getSharedPreferences("resumable_transfers",MODE_PRIVATE).edit().putString(t.id.toString(),
   listOf(t.url,t.filename,t.mime,t.agent,t.cookie,t.referer).joinToString(31.toChar().toString())).apply()
 }
 // The foreground service writes progress to persistent preferences. UI only observes it.
 private fun refreshTransfers(){
  val metadata=getSharedPreferences("resumable_transfers",MODE_PRIVATE).all
  val progress=getSharedPreferences("transfer_status",MODE_PRIVATE)
  for((key,value) in metadata){
   val id=key.toLongOrNull()?:continue
   val raw=(value as? String)?:continue
   val fields=raw.split(31.toChar()).let{parts->
    if(parts.size>=5)parts else raw.split(92.toChar().toString()+"u001f")
   }
   if(fields.size<5)continue
   val t=transfers[id]?:Transfer(id,fields[0],fields[1],fields[2],fields[3],fields[4],fields.getOrElse(5){""}).also{transfers[id]=it}
   val status=progress.getString(key,null)
   val info=try{org.json.JSONObject(status?:"{}")}catch(_:Exception){org.json.JSONObject()}
   t.done=info.optLong("done",File(cacheDir,"transfer_" + id + ".part").length())
   t.size=info.optLong("size",-1)
   t.speed=info.optLong("speed",0)
   t.uri=info.optString("uri","")
   t.state=info.optString("state","Paused")
  }
  transfers.keys.toList().filter{!metadata.containsKey(it.toString())}.forEach{transfers.remove(it)}
 }
 private fun restoreTransfers(){refreshTransfers()}
 private fun sendTransferAction(action:String,id:Long,foreground:Boolean=false){
  val intent=Intent(this,DownloadService::class.java).apply{
   this.action=action;putExtra(DownloadService.EXTRA_ID,id)
  }
  try{
   if(foreground)androidx.core.content.ContextCompat.startForegroundService(this,intent)
   else startService(intent)
  }catch(e:Exception){
   val error="Failed: " + (e.message?:"cannot start background service")
   transfers[id]?.state=error
   getSharedPreferences("transfer_status",MODE_PRIVATE).edit().putString(id.toString(),
    org.json.JSONObject().apply{put("state",error);put("size",-1);put("done",0);put("speed",0)}.toString()).apply()
   Toast.makeText(this,"Download service error: " + e.message,Toast.LENGTH_LONG).show()
  }
 }
 private fun pauseTransfer(t:Transfer){
  t.state="Paused"
  sendTransferAction(DownloadService.ACTION_PAUSE,t.id)
 }
 private fun removeTransfer(t:Transfer){
  transfers.remove(t.id)
  sendTransferAction(DownloadService.ACTION_REMOVE,t.id)
 }
 private fun startTransfer(t:Transfer){
  if(t.state=="Downloading"||t.state=="Completed")return
  if(android.os.Build.VERSION.SDK_INT>=33 &&
      checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED){
   requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),2602)
  }
  t.state="Connecting"
  sendTransferAction(DownloadService.ACTION_START,t.id,true)
 }

 private val downloadManager by lazy{getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager}
 private val uiHandler=android.os.Handler(android.os.Looper.getMainLooper())
 @SuppressLint("SetJavaScriptEnabled")
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  WindowCompat.setDecorFitsSystemWindows(window,false)
  window.statusBarColor=Color.BLACK
  window.navigationBarColor=Color.BLACK
  window.decorView.systemUiVisibility=0
  window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN or WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
  restoreTransfers()
  val saved=getSharedPreferences("app_downloads",MODE_PRIVATE)
  saved.all.forEach{(key,value)->key.toLongOrNull()?.let{id->if(value is String)downloads[id]=Pair(value,SystemClock.elapsedRealtime())}}

  // Generated app chrome: immersive WebView, AMOLED address bar, collapsible dock.
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(Color.BLACK)}
  val addressBar=LinearLayout(this).apply{
   orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL
   setPadding(13.dp(),6.dp(),13.dp(),6.dp());setBackgroundColor(Color.BLACK)
  }
  val addressIcon=TextView(this).apply{
   text="◎";textSize=22f;gravity=android.view.Gravity.CENTER
   setTextColor(0xff00E5EE.toInt())
  }
  addressBar.addView(addressIcon,LinearLayout.LayoutParams(34.dp(),44.dp()))
  currentUrlLabel=TextView(this).apply{
   text="Opening website...";textSize=13f;maxLines=1
   ellipsize=android.text.TextUtils.TruncateAt.MIDDLE
   gravity=android.view.Gravity.CENTER_VERTICAL
   setTextColor(0xffE8F6F7.toInt())
   setPadding(13.dp(),0,13.dp(),0)
   background=rounded(0xff151C1F.toInt(),18)
   setOnClickListener{
    val input=EditText(this@MainActivity).apply{
     setSingleLine(true);setText(tabs.getOrNull(active)?.url?:home)
     inputType=android.text.InputType.TYPE_TEXT_VARIATION_URI
    }
    AlertDialog.Builder(this@MainActivity).setTitle("Open website").setView(input)
     .setPositiveButton("Go"){_,_->
      val entered=input.text.toString().trim()
      val target=if(entered.startsWith("http://")||entered.startsWith("https://"))entered else "https://$entered"
      if(Uri.parse(target).host.isNullOrBlank())Toast.makeText(this@MainActivity,"Invalid URL",Toast.LENGTH_SHORT).show()
      else tabs.getOrNull(active)?.loadUrl(target)
     }.setNegativeButton("Cancel",null).show()
   }
  }
  addressBar.addView(currentUrlLabel,LinearLayout.LayoutParams(0,44.dp(),1f))
  val addressMenu=TextView(this).apply{
   text="⋮";textSize=24f;gravity=android.view.Gravity.CENTER;setTextColor(Color.WHITE)
   setOnClickListener{setControlsExpanded(!controlsExpanded)}
  }
  addressBar.addView(addressMenu,LinearLayout.LayoutParams(38.dp(),44.dp()))
  root.addView(addressBar,LinearLayout.LayoutParams(-1,56.dp()))
  addressBarView=addressBar

  val overlay=FrameLayout(this)
  container=FrameLayout(this)
  overlay.addView(container,FrameLayout.LayoutParams(-1,-1))
  val controls=LinearLayout(this).apply{
   orientation=LinearLayout.VERTICAL
   setPadding(14.dp(),16.dp(),14.dp(),14.dp())
   background=rounded(0xff0A1114.toInt(),23,0xff008E98.toInt())
   elevation=18.dp().toFloat()
  }
  topBar=controls
  val panelHeading=TextView(this).apply{
   text="QUICK ACTIONS";textSize=13f;setTextColor(0xff00E5EE.toInt())
   setPadding(8.dp(),4.dp(),8.dp(),12.dp())
  }
  controls.addView(panelHeading)
  fun actionRow(symbol:String,title:String,action:()->Unit){
   val item=LinearLayout(this).apply{
    orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL
    setPadding(13.dp(),11.dp(),13.dp(),11.dp())
    background=rounded(0xff172126.toInt(),14)
    setOnClickListener{setControlsExpanded(false);action()}
   }
   item.addView(TextView(this).apply{
    text=symbol;textSize=22f;gravity=android.view.Gravity.CENTER_VERTICAL
    setTextColor(0xff00E5EE.toInt())
   },LinearLayout.LayoutParams(37.dp(),-2))
   item.addView(TextView(this).apply{
    text=title;textSize=15f;setTextColor(Color.WHITE)
   },LinearLayout.LayoutParams(0,-2,1f))
   controls.addView(item,LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=6.dp()})
  }
  actionRow("⊞","New Tab"){openTab(getSharedPreferences("web_settings",MODE_PRIVATE).getString("homepage",home)?:home,true)}
  actionRow("↻","Refresh"){tabs.getOrNull(active)?.reload()}
  actionRow("▣","Desktop Mode"){
   val p=getSharedPreferences("web_settings",MODE_PRIVATE)
   val next=!p.getBoolean("desktop",false)
   p.edit().putBoolean("desktop",next).apply()
   tabs.forEach{w->
    val ua=WebSettings.getDefaultUserAgent(this)
    w.settings.userAgentString=if(next)ua.replace("Mobile ","").replace("; wv","") else ua
   }
   tabs.getOrNull(active)?.reload()
  }
  actionRow("⛶","Fullscreen"){
   val flags=window.decorView.systemUiVisibility
   val full=flags and View.SYSTEM_UI_FLAG_FULLSCREEN!=0
   window.decorView.systemUiVisibility=if(full)0 else (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
  }
  actionRow("↗","Share"){
   val intent=Intent(Intent.ACTION_SEND).apply{type="text/plain";putExtra(Intent.EXTRA_TEXT,tabs.getOrNull(active)?.url?:home)}
   startActivity(Intent.createChooser(intent,"Share page"))
  }
  actionRow("▶","Download Videos"){showAvailableVideos()}
  actionRow("⚙","Settings"){showSettings()}
  val closePanel=TextView(this).apply{
   text="Close  ×";textSize=14f;gravity=android.view.Gravity.END
   setTextColor(0xff00E5EE.toInt());setPadding(8.dp(),10.dp(),8.dp(),4.dp())
   setOnClickListener{setControlsExpanded(false)}
  }
  controls.addView(closePanel)
  controls.visibility=View.GONE
  downloadButton=TextView(this).apply{visibility=View.GONE}
  tabButton=TextView(this).apply{text="▢";visibility=View.GONE}

  // Four primary navigation actions and a dedicated collapse chevron.
  floatingDock=LinearLayout(this).apply{
   orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL
   setPadding(6.dp(),5.dp(),6.dp(),5.dp())
   background=rounded(0xee10191c.toInt(),27,0xff246069.toInt())
   elevation=16.dp().toFloat()
  }
  fun dockAction(symbol:String,label:String,activeItem:Boolean=false,action:()->Unit){
   val item=LinearLayout(this).apply{
    orientation=LinearLayout.VERTICAL;gravity=android.view.Gravity.CENTER
    background=if(activeItem)rounded(0xff103b40.toInt(),18) else rounded(0x0010191c,18)
    setOnClickListener{setControlsExpanded(false);action()}
   }
   item.addView(TextView(this).apply{
    text=symbol;textSize=23f;gravity=android.view.Gravity.CENTER
    setTextColor(if(activeItem)0xff00E5EE.toInt() else Color.WHITE)
   },LinearLayout.LayoutParams(-1,31.dp()))
   item.addView(TextView(this).apply{
    text=label;textSize=10f;gravity=android.view.Gravity.CENTER
    setTextColor(if(activeItem)0xff00E5EE.toInt() else 0xffCBD8DB.toInt())
   })
   floatingDock.addView(item,LinearLayout.LayoutParams(0,-1,1f))
  }
  dockAction("⌂","Home",true){
   tabs.getOrNull(active)?.loadUrl(getSharedPreferences("web_settings",MODE_PRIVATE).getString("homepage",home)?:home)
  }
  dockAction("▢","Tabs"){showTabs()}
  dockAction("↓","Downloads"){showDownloads()}
  dockAction("☰","Menu"){setControlsExpanded(!controlsExpanded)}
  floatingDock.addView(TextView(this).apply{
   text="⌄";textSize=24f;gravity=android.view.Gravity.CENTER
   setTextColor(0xff00E5EE.toInt())
   contentDescription="Collapse navigation dock"
   setOnClickListener{setControlsExpanded(false);setDockExpanded(false)}
  },LinearLayout.LayoutParams(29.dp(),-1))

  // Collapsed state is a small persistent pill. Tapping it restores all dock actions.
  floatingHandle=TextView(this).apply{
   text="⌃";textSize=28f;gravity=android.view.Gravity.CENTER
   setTextColor(0xff00E5EE.toInt())
   contentDescription="Expand navigation dock"
   background=rounded(0xff10191c.toInt(),30,0xff00E5EE.toInt())
   elevation=16.dp().toFloat()
   visibility=View.GONE
   setOnClickListener{setDockExpanded(true)}
  }
  val dockWidth=(resources.displayMetrics.widthPixels-24.dp()).coerceAtMost(420.dp())
  overlay.addView(controls,FrameLayout.LayoutParams(286.dp(),-2,android.view.Gravity.BOTTOM or android.view.Gravity.END).apply{
   bottomMargin=99.dp();rightMargin=13.dp()
  })
  overlay.addView(floatingDock,FrameLayout.LayoutParams(dockWidth,68.dp(),android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL).apply{
   bottomMargin=17.dp()
  })
  overlay.addView(floatingHandle,FrameLayout.LayoutParams(58.dp(),48.dp(),android.view.Gravity.BOTTOM or android.view.Gravity.END).apply{
   bottomMargin=22.dp();rightMargin=16.dp()
  })
  root.addView(overlay,LinearLayout.LayoutParams(-1,0,1f))
  setContentView(root)
  ViewCompat.setOnApplyWindowInsetsListener(root){view,insets->
   val bars=insets.getInsets(WindowInsetsCompat.Type.systemBars())
   view.setPadding(bars.left,bars.top,bars.right,bars.bottom)
   insets
  }
  dockExpanded=getSharedPreferences("web_settings",MODE_PRIVATE).getBoolean("dock_expanded",true)
  setDockExpanded(dockExpanded)
  val settingsPrefs=getSharedPreferences("web_settings",MODE_PRIVATE)
  val savedTabs=settingsPrefs.getString("saved_tabs","")?:""
  if(settingsPrefs.getBoolean("restore_tabs",true)&&savedTabs.isNotBlank()){
   savedTabs.split("|").filter{it.startsWith("http")}.take(12).forEachIndexed{index,url->openTab(url,index==0)}
  }
  if(tabs.isEmpty())openTab(settingsPrefs.getString("homepage",home)?:home,true)
  monitorDownloads()
  onBackPressedDispatcher.addCallback(this,object:OnBackPressedCallback(true){override fun handleOnBackPressed(){
   val current=tabs.getOrNull(active)
   if(fullscreenCustomView!=null)exitHtmlFullscreen()
   else if(offlineOverlay!=null)clearOfflinePage()
   else if(current?.canGoBack()==true)current.goBack()
   else if(tabs.size>1)closeTab(active)
   else finish()
  }})
 }
 @SuppressLint("SetJavaScriptEnabled")
 override fun onStop(){
  super.onStop()
  getSharedPreferences("web_settings",MODE_PRIVATE).edit()
   .putString("saved_tabs",tabs.mapNotNull{it.url?.takeIf{u->u.startsWith("http")}}.joinToString("|")).apply()
 }

 private fun networkAvailable():Boolean{
  val cm=getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  val cap=cm.getNetworkCapabilities(cm.activeNetwork)?:return false
  return cap.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
   (android.os.Build.VERSION.SDK_INT<23 || cap.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
 }
 private fun clearOfflinePage(){
  offlineOverlay?.let{(it.parent as?android.view.ViewGroup)?.removeView(it)}
  offlineOverlay=null
 }
 private fun showOfflinePage(web:WebView,address:String,description:String){
  if(tabs.getOrNull(active)!==web)return
  clearOfflinePage()
  val panel=LinearLayout(this).apply{
   orientation=LinearLayout.VERTICAL;gravity=android.view.Gravity.CENTER
   setPadding(28.dp(),28.dp(),28.dp(),28.dp())
   setBackgroundColor(Color.BLACK)
  }
  panel.addView(TextView(this).apply{
   text="◌";textSize=66f;setTextColor(0xff00E5EE.toInt())
   gravity=android.view.Gravity.CENTER
  })
  panel.addView(TextView(this).apply{
   text=if(networkAvailable())"Website unavailable" else "You're offline"
   textSize=25f;gravity=android.view.Gravity.CENTER;setTextColor(Color.WHITE)
  })
  panel.addView(TextView(this).apply{
   text=description.take(160)+"\n"+address.take(150)
   textSize=13f;gravity=android.view.Gravity.CENTER;setTextColor(0xffA8B8BE.toInt())
   setPadding(0,16.dp(),0,30.dp())
  })
  panel.addView(TextView(this).apply{
   text="↻   Try Again";textSize=16f;gravity=android.view.Gravity.CENTER
   setTextColor(Color.BLACK);background=rounded(0xff00E5EE.toInt(),25)
   setOnClickListener{clearOfflinePage();web.reload()}
  },LinearLayout.LayoutParams(-1,54.dp()))
  panel.addView(TextView(this).apply{
   text="Network settings";textSize=14f;gravity=android.view.Gravity.CENTER
   setTextColor(0xff00E5EE.toInt());setPadding(0,20.dp(),0,8.dp())
   setOnClickListener{
    startActivity(Intent(android.provider.Settings.ACTION_WIFI_SETTINGS))
   }
  })
  offlineOverlay=panel
  container.addView(panel,FrameLayout.LayoutParams(-1,-1))
 }
 private fun captureTabPreview(web:WebView){
  if(web.width<20||web.height<20||tabs.getOrNull(active)!==web)return
  runCatching{
   val bmp=Bitmap.createBitmap(240,140,Bitmap.Config.RGB_565)
   val canvas=Canvas(bmp)
   canvas.drawColor(Color.WHITE)
   canvas.scale(240f/web.width,140f/web.height)
   web.draw(canvas)
   tabPreviews[web]=bmp
  }
 }
 private fun enterHtmlFullscreen(view:View,callback:WebChromeClient.CustomViewCallback){
  if(fullscreenCustomView!=null){callback.onCustomViewHidden();return}
  fullscreenCustomView=view
  fullscreenCallback=callback
  setControlsExpanded(false)
  (window.decorView as android.view.ViewGroup).addView(view,
   android.view.ViewGroup.LayoutParams(-1,-1))
  addressBarView.visibility=View.GONE
  floatingDock.visibility=View.GONE
  floatingHandle.visibility=View.GONE
  window.decorView.systemUiVisibility=View.SYSTEM_UI_FLAG_FULLSCREEN or
   View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
 }
 private fun exitHtmlFullscreen(){
  fullscreenCustomView?.let{(it.parent as?android.view.ViewGroup)?.removeView(it)}
  fullscreenCustomView=null
  fullscreenCallback?.onCustomViewHidden()
  fullscreenCallback=null
  window.decorView.systemUiVisibility=0
  addressBarView.visibility=View.VISIBLE
  setChromeVisible(true)
  if(dockExpanded)floatingDock.visibility=View.VISIBLE
  else floatingHandle.visibility=View.VISIBLE
 }
 private fun isVideoFile(name:String,mime:String):Boolean =
  mime.startsWith("video/",true) ||
   listOf(".mp4",".mkv",".webm",".avi",".mov",".m4v",".3gp").any{name.endsWith(it,true)}
 private fun openDownloadedFile(uri:Uri,name:String,mime:String){
  val intent=if(isVideoFile(name,mime)){
   Intent(this,VideoPlayerActivity::class.java).apply{
    data=uri
    putExtra("video_title",name)
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
   }
  }else{
   Intent(Intent.ACTION_VIEW).apply{
    setDataAndType(uri,mime.ifBlank{"*/*"})
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
   }
  }
  runCatching{startActivity(intent)}.onFailure{
   Toast.makeText(this,"No compatible player for this file",Toast.LENGTH_LONG).show()
  }
 }
 private fun createWebView():WebView{
  val w=WebView(this)
  w.settings.apply{javaScriptEnabled=true;domStorageEnabled=true;databaseEnabled=true;setSupportMultipleWindows(true);javaScriptCanOpenWindowsAutomatically=true;useWideViewPort=true;loadWithOverviewMode=true;mediaPlaybackRequiresUserGesture=false}
  val settingsPrefs=getSharedPreferences("web_settings",MODE_PRIVATE)
  w.settings.textZoom=settingsPrefs.getInt("text_scale",100)
  if(settingsPrefs.getBoolean("desktop",false)){
   w.settings.userAgentString=w.settings.userAgentString.replace("Mobile ","").replace("; wv","")
  }
  CookieManager.getInstance().apply{setAcceptCookie(true);setAcceptThirdPartyCookies(w,true)}
  // Edge swipes navigate history. A deliberate downward pull at page top refreshes.
  var touchX=0f
  var touchY=0f
  w.setOnTouchListener{_,event->
   when(event.actionMasked){
    MotionEvent.ACTION_DOWN->{touchX=event.x;touchY=event.y;false}
    MotionEvent.ACTION_UP->{
     val dx=event.x-touchX
     val dy=event.y-touchY
     val edge=32.dp().toFloat()
     when{
      kotlin.math.abs(dx)>96.dp() && kotlin.math.abs(dy)<75.dp() &&
       touchX<edge && dx>0 && w.canGoBack()->{w.goBack();true}
      kotlin.math.abs(dx)>96.dp() && kotlin.math.abs(dy)<75.dp() &&
       touchX>w.width-edge && dx<0 && w.canGoForward()->{w.goForward();true}
      w.scrollY<=0 && dy>145.dp() && kotlin.math.abs(dx)<65.dp() &&
       touchY>65.dp() && touchY<w.height*0.65f->{w.reload();true}
      else->false
     }
    }
    else->false
   }
  }
  // Positive scroll delta = content moving upwards: hide app chrome.
  // Negative scroll delta = content moving downwards: reveal chrome again.
  var scrollDistance=0
  var previousDirection=0
  w.setOnScrollChangeListener{_,_,scrollY,_,oldScrollY->
   if(tabs.getOrNull(active)===w&&!controlsExpanded){
    val delta=scrollY-oldScrollY
    if(scrollY<=2){scrollDistance=0;setChromeVisible(true)}
    else if(kotlin.math.abs(delta)>1){
     val direction=if(delta>0)1 else -1
     if(direction!=previousDirection)scrollDistance=0
     previousDirection=direction
     scrollDistance+=kotlin.math.abs(delta)
     if(scrollDistance>=24.dp()){
      setChromeVisible(direction<0)
      scrollDistance=0
     }
    }
   }
  }
  w.webViewClient=object:WebViewClient(){
   override fun onPageStarted(view:WebView,url:String?,favicon:android.graphics.Bitmap?){
    if(tabs.getOrNull(active)===view){clearOfflinePage();updateAddressBar()}
   }
   override fun onPageFinished(view:WebView,url:String?){
    if(tabs.getOrNull(active)===view){
     updateAddressBar()
     view.postDelayed({captureTabPreview(view)},450)
    }
   }
   override fun onReceivedError(view:WebView,request:WebResourceRequest,error:WebResourceError){
    super.onReceivedError(view,request,error)
    if(request.isForMainFrame)
     showOfflinePage(view,request.url.toString(),error.description?.toString()?:"Could not reach server")
   }
   override fun onReceivedHttpError(view:WebView,request:WebResourceRequest,response:WebResourceResponse){
    super.onReceivedHttpError(view,request,response)
    if(request.isForMainFrame && response.statusCode>=500)
     showOfflinePage(view,request.url.toString(),"Server error " + response.statusCode)
   }
   override fun shouldOverrideUrlLoading(view:WebView,request:WebResourceRequest):Boolean{
    val uri=request.url
    if(uri.scheme!="http"&&uri.scheme!="https"){runCatching{startActivity(Intent(Intent.ACTION_VIEW,uri))};return true}
    return false
   }
  }
  w.webChromeClient=object:WebChromeClient(){
   override fun onShowCustomView(view:View,callback:CustomViewCallback){
    enterHtmlFullscreen(view,callback)
   }
   override fun onHideCustomView(){exitHtmlFullscreen()}

   override fun onCreateWindow(view:WebView,isDialog:Boolean,isUserGesture:Boolean,resultMsg:android.os.Message):Boolean{
    if(!isUserGesture)return false
    val child=createWebView()
    tabs.add(child)
    updateCount()
    val transport=resultMsg.obj as WebView.WebViewTransport
    transport.webView=child
    resultMsg.sendToTarget()
    Toast.makeText(this@MainActivity,"Opened background tab",Toast.LENGTH_SHORT).show()
    return true
   }
   override fun onCloseWindow(window:WebView){val i=tabs.indexOf(window);if(i>=0)closeTab(i)}
  }
  w.setDownloadListener{url,agent,disposition,mime,_->
   try{
    if(getSharedPreferences("web_settings",MODE_PRIVATE).getBoolean("wifi_only",false)){
     val cm=getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
     val network=cm.getNetworkCapabilities(cm.activeNetwork)
     if(network?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)!=true){
      Toast.makeText(this,"Wi-Fi required by download settings",Toast.LENGTH_LONG).show()
      return@setDownloadListener
     }
    }
    val filename=URLUtil.guessFileName(url,disposition,mime)
    val id=System.currentTimeMillis()
    val transfer=Transfer(id,url,filename,mime?: "",agent?:w.settings.userAgentString,
     CookieManager.getInstance().getCookie(url)?:"",w.url?:"")
    transfers[id]=transfer
    persistTransfer(transfer)
    startTransfer(transfer)
    downloadButton.visibility=View.VISIBLE
    Toast.makeText(this,"Download started: $filename",Toast.LENGTH_LONG).show()
   }catch(e:Exception){Toast.makeText(this,"Download failed to start",Toast.LENGTH_LONG).show()}
  }
  return w
 }
 private fun openTab(url:String,foreground:Boolean){
  val w=createWebView();tabs.add(w);w.loadUrl(url)
  if(foreground)activate(tabs.lastIndex) else updateCount()
 }
 private fun activate(index:Int){
  if(index !in tabs.indices)return
  tabs.getOrNull(active)?.let{captureTabPreview(it)}
  active=index;clearOfflinePage();container.removeAllViews()
  val w=tabs[index];(w.parent as? android.view.ViewGroup)?.removeView(w)
  container.addView(w,FrameLayout.LayoutParams(-1,-1));updateCount();updateAddressBar();setChromeVisible(true)
 }
 private fun updateCount(){tabButton.text="▢ ${tabs.size}"}
 private fun closeAllOtherTabs(){
  // Preserve the selected WebView object and its state; destroy only background tabs.
  val current=tabs.getOrNull(active)?:return
  if(tabs.size<=1)return
  tabs.toList().filter{it!==current}.forEach{other->
   (other.parent as? android.view.ViewGroup)?.removeView(other)
   other.stopLoading()
   tabPreviews.remove(other)
   other.destroy()
  }
  tabs.clear()
  tabs.add(current)
  active=0
  activate(0)
  getSharedPreferences("web_settings",MODE_PRIVATE).edit()
   .putString("saved_tabs",current.url?:home).apply()
 }
 private fun closeTab(index:Int){
  if(index !in tabs.indices)return
  val w=tabs.removeAt(index)
  (w.parent as? android.view.ViewGroup)?.removeView(w);tabPreviews.remove(w);w.destroy()
  if(tabs.isEmpty()){openTab(getSharedPreferences("web_settings",MODE_PRIVATE).getString("homepage",home)?:home,true);return}
  if(index<active)active--
  if(index==active||active>=tabs.size)active=active.coerceAtMost(tabs.lastIndex)
  activate(active)
 }
 private fun setControlsExpanded(expanded:Boolean){
  controlsExpanded=expanded
  topBar.visibility=if(expanded)View.VISIBLE else View.GONE
  if(::floatingHandle.isInitialized)
   floatingHandle.visibility=if(expanded||dockExpanded||!chromeVisible)View.GONE else View.VISIBLE
  uiHandler.removeCallbacks(collapseControls)
  if(expanded)uiHandler.postDelayed(collapseControls,8000)
 }
 // Manual collapse is persisted. Scroll-triggered auto-hide does not change that choice.
 private fun setDockExpanded(expanded:Boolean){
  dockExpanded=expanded
  if(::floatingDock.isInitialized){
   floatingDock.animate().cancel()
   floatingDock.visibility=if(expanded&&chromeVisible)View.VISIBLE else View.GONE
   floatingDock.translationY=0f;floatingDock.alpha=1f
  }
  if(::floatingHandle.isInitialized){
   floatingHandle.animate().cancel()
   floatingHandle.visibility=if(!expanded&&!controlsExpanded&&chromeVisible)View.VISIBLE else View.GONE
   floatingHandle.translationY=0f;floatingHandle.alpha=1f
  }
  getSharedPreferences("web_settings",MODE_PRIVATE).edit().putBoolean("dock_expanded",expanded).apply()
 }
 // Smoothly shrink the address bar to free vertical screen space, and slide the
 // floating dock/restore handle away. Scrolling back reverses both animations.
 private fun setChromeVisible(visible:Boolean){
  if(chromeVisible==visible)return
  chromeVisible=visible
  if(!visible)setControlsExpanded(false)
  if(::addressBarView.isInitialized){
   chromeAnimator?.cancel()
   val startHeight=addressBarView.layoutParams.height
   val fullHeight=56.dp()
   chromeAnimator=android.animation.ValueAnimator.ofInt(startHeight,if(visible)fullHeight else 0).apply{
    duration=230L
    interpolator=android.view.animation.DecelerateInterpolator()
    addUpdateListener{animation->
     val height=animation.animatedValue as Int
     addressBarView.layoutParams=addressBarView.layoutParams.apply{this.height=height}
     addressBarView.alpha=(height.toFloat()/fullHeight).coerceIn(0f,1f)
    }
    start()
   }
  }
  if(::floatingDock.isInitialized){
   val showDock=visible&&dockExpanded
   floatingDock.animate().cancel()
   if(showDock)floatingDock.visibility=View.VISIBLE
   floatingDock.animate().translationY(if(showDock)0f else 100.dp().toFloat())
    .alpha(if(showDock)1f else 0f).setDuration(230L)
    .withEndAction{if(!showDock)floatingDock.visibility=View.GONE}.start()
  }
  if(::floatingHandle.isInitialized){
   val showHandle=visible&&!dockExpanded&&!controlsExpanded
   floatingHandle.animate().cancel()
   if(showHandle)floatingHandle.visibility=View.VISIBLE
   floatingHandle.animate().translationY(if(showHandle)0f else 85.dp().toFloat())
    .alpha(if(showHandle)1f else 0f).setDuration(230L)
    .withEndAction{if(!showHandle)floatingHandle.visibility=View.GONE}.start()
  }
 }
 private fun updateAddressBar(){
  if(::currentUrlLabel.isInitialized)currentUrlLabel.text=tabs.getOrNull(active)?.url?:home
 }
 private fun showTabs(){
  tabs.getOrNull(active)?.let{captureTabPreview(it)}
  val panel=LinearLayout(this).apply{
   orientation=LinearLayout.VERTICAL;setPadding(20.dp(),20.dp(),20.dp(),22.dp())
   setBackgroundColor(Color.BLACK)
  }
  val dialog=AlertDialog.Builder(this).setView(panel).create()
  val header=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL}
  header.addView(TextView(this).apply{
   text="▢   Tabs";textSize=25f;setTextColor(0xff00E5EE.toInt())
  },LinearLayout.LayoutParams(0,-2,1f))
  header.addView(TextView(this).apply{
   text="×";textSize=29f;setTextColor(Color.WHITE);setPadding(12.dp(),0,4.dp(),0)
   setOnClickListener{dialog.dismiss()}
  })
  panel.addView(header)
  panel.addView(TextView(this).apply{
   text=tabs.size.toString()+" Tabs Open";textSize=13f;setTextColor(0xffB1C4CA.toInt())
   setPadding(0,16.dp(),0,14.dp())
  })
  // Bulk tab action is intentionally explicit: never close the current tab.
  panel.addView(TextView(this).apply{
   text="Close All Other Tabs  ·  Keep current tab"
   textSize=14f
   gravity=android.view.Gravity.CENTER_VERTICAL
   setPadding(16.dp(),12.dp(),16.dp(),12.dp())
   setTextColor(if(tabs.size>1)0xff00E5EE.toInt() else 0xff657A80.toInt())
   background=rounded(0xff111B1E.toInt(),14,0xff263338.toInt())
   isEnabled=tabs.size>1
   setOnClickListener{
    val others=tabs.size-1
    AlertDialog.Builder(this@MainActivity)
     .setTitle("Close all other tabs?")
     .setMessage("Close $others other tab"+if(others==1)"?" else "s? Your current tab will stay open.")
     .setNegativeButton("Cancel",null)
     .setPositiveButton("Close other tabs"){_,_->
      closeAllOtherTabs()
      dialog.dismiss()
      showTabs()
     }.show()
   }
  },LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=14.dp()})
  val scroll=ScrollView(this).apply{isFillViewport=true}
  val list=LinearLayout(this@MainActivity).apply{orientation=LinearLayout.VERTICAL}
  scroll.addView(list)
  panel.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
  tabs.toList().forEachIndexed{index,w->
   val row=LinearLayout(this).apply{
    orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL
    setPadding(15.dp(),14.dp(),12.dp(),14.dp())
    background=rounded(if(index==active)0xff103037.toInt() else 0xff151D20.toInt(),18,
     if(index==active)0xff00E5EE.toInt() else 0xff263338.toInt())
   }
   val preview=tabPreviews[w]
   if(preview!=null){
    row.addView(ImageView(this).apply{
     setImageBitmap(preview);scaleType=ImageView.ScaleType.CENTER_CROP
     background=rounded(0xff273338.toInt(),12)
    },LinearLayout.LayoutParams(94.dp(),76.dp()).apply{marginEnd=12.dp()})
   }else{
    row.addView(TextView(this).apply{
     text="◎";textSize=30f;gravity=android.view.Gravity.CENTER
     setTextColor(0xff00E5EE.toInt())
     background=rounded(0xff202C31.toInt(),12)
    },LinearLayout.LayoutParams(94.dp(),76.dp()).apply{marginEnd=12.dp()})
   }
   val textColumn=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
   textColumn.addView(TextView(this).apply{
    text=(if(index==active)"●  " else "")+(w.title?:w.url?:"New tab")
    setTextColor(Color.WHITE);maxLines=2;ellipsize=android.text.TextUtils.TruncateAt.END;textSize=16f
   })
   textColumn.addView(TextView(this).apply{
    text=w.url?:"";maxLines=1;ellipsize=android.text.TextUtils.TruncateAt.MIDDLE
    setTextColor(0xffA4B8BE.toInt());textSize=12f;setPadding(0,5.dp(),0,0)
   })
   textColumn.setOnClickListener{activate(index);dialog.dismiss()}
   row.addView(textColumn,LinearLayout.LayoutParams(0,-2,1f))
   row.addView(TextView(this).apply{
    text="×";textSize=25f;gravity=android.view.Gravity.CENTER
    setTextColor(0xffCCDADD.toInt())
    setOnClickListener{closeTab(index);dialog.dismiss();showTabs()}
   },LinearLayout.LayoutParams(41.dp(),46.dp()))
   list.addView(row,LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=10.dp()})
  }
  panel.addView(TextView(this).apply{
   text="+  New Tab";textSize=16f;gravity=android.view.Gravity.CENTER
   setTextColor(Color.BLACK);background=rounded(0xff00E5EE.toInt(),25)
   setOnClickListener{
    openTab(getSharedPreferences("web_settings",MODE_PRIVATE).getString("homepage",home)?:home,true)
    dialog.dismiss()
   }
  },LinearLayout.LayoutParams(-1,54.dp()).apply{topMargin=12.dp()})
  dialog.show()
  dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
  dialog.window?.setLayout(-1,-1)
 }
 private fun rounded(fill:Int,radius:Int,stroke:Int=0):GradientDrawable=
  GradientDrawable().apply{setColor(fill);cornerRadius=radius.dp().toFloat();if(stroke!=0)setStroke(1.dp(),stroke)}
 private fun Int.dp()=(this*resources.displayMetrics.density).toInt()
 private fun duration(seconds:Long):String{
  val safe=seconds.coerceAtLeast(0)
  return if(safe>=3600L) String.format(java.util.Locale.US,"%d:%02d:%02d",safe/3600,(safe/60)%60,safe%60)
   else String.format(java.util.Locale.US,"%d:%02d",safe/60,safe%60)
 }
 private fun pretty(bytes:Long):String=when{
  bytes<0->"Unknown"
  bytes<1024->"$bytes B"
  bytes<1048576->String.format("%.1f KB",bytes/1024.0)
  bytes<1073741824->String.format("%.1f MB",bytes/1048576.0)
  else->String.format("%.2f GB",bytes/1073741824.0)
 }
 private fun monitorDownloads(){
  uiHandler.postDelayed(object:Runnable{
   override fun run(){
    refreshTransfers()
    var activeDownload=false
    activeDownload=transfers.values.any{it.state=="Downloading"||it.state=="Retrying"||it.state=="Saving file"||it.state.startsWith("Paused")}
    for(id in downloads.keys){
     runCatching{downloadManager.query(DownloadManager.Query().setFilterById(id))}.getOrNull()?.use{cursor->
      if(cursor.moveToFirst()){
       val state=cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
       if(state==DownloadManager.STATUS_RUNNING||state==DownloadManager.STATUS_PENDING||state==DownloadManager.STATUS_PAUSED)activeDownload=true
      }
     }
    }
    downloadButton.visibility=if(activeDownload)View.VISIBLE else View.GONE
    uiHandler.postDelayed(this,1500)
   }
  },1000)
 }
 private fun blueDialog(dialog:AlertDialog){
  dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
  dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(0xff00E5EE.toInt())
  dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(0xff00E5EE.toInt())
 }

 // Search HTML5 video/source elements and direct video links on the current webpage.
 // This deliberately does not intercept DRM, blob:, HLS or DASH streams.
 private fun showAvailableVideos(){
  val page=tabs.getOrNull(active)?:return
  if(!page.settings.javaScriptEnabled){
   Toast.makeText(this,"Video detection requires JavaScript",Toast.LENGTH_LONG).show()
   return
  }
  val scanScript="""
   (function(){
    const found=[];
    const seen=new Set();
    function add(candidate,title,type,fromPlayer){
     try{
      if(!candidate)return;
      const url=new URL(candidate,document.baseURI).href;
      if(!/^https?:\/\//i.test(url))return;
      const mime=String(type||"").toLowerCase().split(";")[0];
      if(/(mpegurl|dash\+xml|widevine)/i.test(mime))return;
      if(/\.(m3u8|mpd)(?:[?#]|$)/i.test(url))return;
      const direct=/\.(mp4|webm|m4v|mov)(?:[?#]|$)/i.test(url);
      if(!direct&&!fromPlayer&&!/^video\/(mp4|webm|quicktime|x-m4v)$/i.test(mime))return;
      if(seen.has(url))return;
      seen.add(url);
      found.push({url:url,title:String(title||"Website video").trim().slice(0,120),mime:mime});
     }catch(e){}
    }
    document.querySelectorAll("video").forEach(function(video,i){
     const name=(document.title||"Video")+" ("+(i+1)+")";
     add(video.currentSrc||video.src,name,video.getAttribute("type")||"",true);
     video.querySelectorAll("source").forEach(function(source){
      add(source.src,name,source.type||"",true);
     });
    });
    document.querySelectorAll("a[href]").forEach(function(link){
     add(link.href,link.textContent||"Video link","",false);
    });
    return found.slice(0,40);
   })()
  """.trimIndent()
  Toast.makeText(this,"Searching this page for videos…",Toast.LENGTH_SHORT).show()
  page.evaluateJavascript(scanScript){result->
   if(tabs.getOrNull(active)!==page)return@evaluateJavascript
   val candidates=try{
    val decoded=org.json.JSONTokener(result?:"null").nextValue()
    val array=when(decoded){
     is org.json.JSONArray->decoded
     is String->org.json.JSONArray(decoded)
     else->org.json.JSONArray()
    }
    val out=ArrayList<VideoCandidate>()
    val seen=HashSet<String>()
    for(i in 0 until array.length()){
     val item=array.optJSONObject(i)?:continue
     val url=item.optString("url","")
     val uri=Uri.parse(url)
     if((uri.scheme!="https"&&uri.scheme!="http")||uri.host.isNullOrBlank())continue
     if(!seen.add(url))continue
     out.add(VideoCandidate(url,item.optString("title","Website video"),item.optString("mime","")))
    }
    out
   }catch(e:Exception){
    Toast.makeText(this,"Could not inspect this webpage",Toast.LENGTH_LONG).show()
    return@evaluateJavascript
   }
   if(candidates.isEmpty()){
    AlertDialog.Builder(this).setTitle("Download Videos")
     .setMessage("No directly downloadable videos were found on this page. DRM-protected videos, blob links and adaptive streams are not supported.")
     .setPositiveButton("OK",null).show()
   }else{
    val labels=candidates.mapIndexed{index,item->
     val format=when{
      item.mime.contains("webm",true)->"WebM"
      item.mime.contains("mp4",true)->"MP4"
      item.url.substringBefore("?").substringBefore("#").endsWith(".webm",true)->"WebM"
      item.url.substringBefore("?").substringBefore("#").endsWith(".mp4",true)->"MP4"
      else->"Video"
     }
     val name=item.title.ifBlank{"Video " + (index+1)}.take(70)
     (index+1).toString()+". "+name+"  ·  "+format
    }
    AlertDialog.Builder(this).setTitle("Download Videos ("+candidates.size+")")
     .setItems(labels.toTypedArray()){_,which->
      startVideoDownload(page,candidates[which])
     }.setNegativeButton("Cancel",null).show()
   }
  }
 }
 private fun startVideoDownload(page:WebView,video:VideoCandidate){
  val uri=Uri.parse(video.url)
  if((uri.scheme!="https"&&uri.scheme!="http")||uri.host.isNullOrBlank()){
   Toast.makeText(this,"Unsupported video address",Toast.LENGTH_LONG).show()
   return
  }
  if(getSharedPreferences("web_settings",MODE_PRIVATE).getBoolean("wifi_only",false)){
   val cm=getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
   val network=cm.getNetworkCapabilities(cm.activeNetwork)
   if(network?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)!=true){
    Toast.makeText(this,"Wi-Fi required by download settings",Toast.LENGTH_LONG).show()
    return
   }
  }
  val mime=when{
   video.mime.startsWith("video/")->video.mime
   video.url.substringBefore("?").substringBefore("#").endsWith(".webm",true)->"video/webm"
   video.url.substringBefore("?").substringBefore("#").endsWith(".mp4",true)->"video/mp4"
   else->"application/octet-stream"
  }
  val name=URLUtil.guessFileName(video.url,"",mime)
  var id=System.currentTimeMillis()
  while(transfers.containsKey(id))id++
  val transfer=Transfer(id,video.url,name,mime,
   page.settings.userAgentString?:"",CookieManager.getInstance().getCookie(video.url)?:"",page.url?:"")
  transfers[id]=transfer
  persistTransfer(transfer)
  startTransfer(transfer)
  downloadButton.visibility=View.VISIBLE
  Toast.makeText(this,"Video download started: $name",Toast.LENGTH_LONG).show()
  showDownloads()
 }

 private fun styleDownloadAction(view:TextView,kind:Int){
  val cyan=0xff00E5EE.toInt()
  val fill=when(kind){
   1->cyan                      // Resume / Open
   2->0xff2A151A.toInt()       // Remove
   else->0xff112A2C.toInt()    // Pause
  }
  val ink=when(kind){
   1->Color.BLACK
   2->0xffFF9FA9.toInt()
   else->cyan
  }
  val outline=when(kind){2->0xff78414B.toInt();else->0xff167B80.toInt()}
  view.apply{
   textSize=13f;gravity=android.view.Gravity.CENTER
   setTextColor(ink);setTypeface(null,android.graphics.Typeface.BOLD)
   setPadding(19.dp(),0,19.dp(),0)
   background=rounded(fill,22,outline)
   setMinHeight(44.dp())
  }
 }
 private fun showDownloads(){
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(0xff050809.toInt());setPadding(16.dp(),12.dp(),16.dp(),12.dp())}
  val heading=TextView(this).apply{text="Downloads";setTextColor(Color.WHITE);textSize=23f;setPadding(6.dp(),4.dp(),6.dp(),12.dp())}
  val scroll=ScrollView(this)
  val list=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  scroll.addView(list)
  root.addView(heading)
  val historyActions=TextView(this).apply{
   text="Manage downloads  ·  Retry failed / Clear completed"
   setTextColor(0xff00E5EE.toInt());textSize=14f
   setPadding(8.dp(),8.dp(),8.dp(),12.dp())
   setOnClickListener{
    AlertDialog.Builder(this@MainActivity)
     .setTitle("Download manager")
     .setItems(arrayOf("Retry failed downloads","Clear completed history")){_,which->
      if(which==0){
       refreshTransfers()
       val failed=transfers.values.filter{it.state.startsWith("Failed")}
       failed.forEach{startTransfer(it)}
       Toast.makeText(this@MainActivity,failed.size.toString()+" downloads queued",Toast.LENGTH_SHORT).show()
      }else{
       refreshTransfers()
       transfers.values.filter{it.state=="Completed"}.toList().forEach{removeTransfer(it)}
       val finished=downloads.keys.filter{id->
        runCatching{downloadManager.query(DownloadManager.Query().setFilterById(id))}.getOrNull()?.use{cursor->
         if(!cursor.moveToFirst())true else {
          val state=cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
          state==DownloadManager.STATUS_SUCCESSFUL||state==DownloadManager.STATUS_FAILED
         }
        }?:true
       }
       finished.forEach{id->
        downloads.remove(id)
        getSharedPreferences("app_downloads",MODE_PRIVATE).edit().remove(id.toString()).apply()
       }
       Toast.makeText(this@MainActivity,"Completed history cleared; saved files were kept",Toast.LENGTH_SHORT).show()
      }
     }.setNegativeButton("Cancel",null).show()
   }
  }
  root.addView(historyActions)
  root.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
  val dialog=AlertDialog.Builder(this,androidx.appcompat.R.style.Theme_AppCompat_Dialog).setView(root).create()
  refreshTransfers()
  heading.text="‹     Downloads"
  heading.setOnClickListener{dialog.dismiss()}
  val samples=mutableMapOf<Long,ArrayDeque<Pair<Long,Long>>>()
  val refresh=object:Runnable{
   override fun run(){
    if(!dialog.isShowing)return
    refreshTransfers()
    list.removeAllViews()
    transfers.values.sortedByDescending{it.id}.forEach{t->
     val card=LinearLayout(this@MainActivity).apply{
      orientation=LinearLayout.VERTICAL;setPadding(16.dp(),14.dp(),16.dp(),14.dp())
      background=rounded(0xff151E21.toInt(),18)
     }
     card.addView(TextView(this@MainActivity).apply{text=t.filename;setTextColor(Color.WHITE);textSize=16f})
     val pct=if(t.size>0)(t.done*100/t.size).toInt().coerceIn(0,100) else 0
     card.addView(TextView(this@MainActivity).apply{
      text="${t.state} • ${pretty(t.done)} / ${if(t.size>0)pretty(t.size) else "Unknown"}"
      setTextColor(0xffADBDC1.toInt());textSize=13f
     })
     card.addView(ProgressBar(this@MainActivity,null,android.R.attr.progressBarStyleHorizontal).apply{
      isIndeterminate=t.size<=0&&(t.state=="Downloading"||t.state=="Connecting"||t.state.startsWith("Retrying"));max=100;progress=pct
     })
     val eta=if(t.speed>0&&t.size>t.done)" • ${duration((t.size-t.done)/t.speed)} remaining" else ""
     card.addView(TextView(this@MainActivity).apply{
      text=if(t.state=="Downloading"&&t.speed>0)"${pretty(t.speed)}/s$eta" else if(t.state=="Downloading"||t.state=="Connecting")"Waiting for server…" else t.state
      setTextColor(0xff00E5EE.toInt());textSize=12f
     })
     val actions=LinearLayout(this@MainActivity).apply{orientation=LinearLayout.HORIZONTAL}
     if(t.state=="Downloading"||t.state=="Connecting"||t.state.startsWith("Retrying")||t.state=="Saving file"){
      actions.addView(TextView(this@MainActivity).apply{text="Ⅱ Pause";styleDownloadAction(this,0);setOnClickListener{pauseTransfer(t)}})
     }else if(t.state.startsWith("Paused")||t.state.startsWith("Failed")){
      actions.addView(TextView(this@MainActivity).apply{text="▶ Resume";styleDownloadAction(this,1);setOnClickListener{startTransfer(t)}})
     }
     if(t.state=="Completed"&&t.uri.startsWith("content://")){
      actions.addView(TextView(this@MainActivity).apply{text=if(isVideoFile(t.filename,t.mime))"▶ Play" else "Open";styleDownloadAction(this,1);setOnClickListener{
       openDownloadedFile(Uri.parse(t.uri),t.filename,t.mime)
      }})
     }
     actions.addView(TextView(this@MainActivity).apply{text="× Remove";styleDownloadAction(this,2);setOnClickListener{removeTransfer(t)}})
     for(i in 0 until actions.childCount){
      actions.getChildAt(i).layoutParams=LinearLayout.LayoutParams(-2,44.dp()).apply{marginEnd=9.dp()}
     }
     card.addView(actions)
     list.addView(card,LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=10.dp()})
    }
    if(downloads.isEmpty()&&transfers.isEmpty()){
     list.addView(TextView(this@MainActivity).apply{text="No downloads yet";setTextColor(Color.LTGRAY);textSize=16f;setPadding(12.dp(),28.dp(),12.dp(),28.dp())})
    }
    var activeHeader=false
    var historyHeader=false
    val ordered=downloads.toList().asReversed().sortedBy{(id,_)->
     runCatching{downloadManager.query(DownloadManager.Query().setFilterById(id))}.getOrNull()?.use{cursor->
      if(!cursor.moveToFirst())1 else {
       val state=cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
       if(state==DownloadManager.STATUS_SUCCESSFUL||state==DownloadManager.STATUS_FAILED)1 else 0
      }
     }?:1
    }
    for((id,info) in ordered){
     val cursor=runCatching{downloadManager.query(DownloadManager.Query().setFilterById(id))}.getOrNull()
     cursor?.use{c->
      if(c.moveToFirst()){
       val status=c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
       val done=c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
       val total=c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
       val now=SystemClock.elapsedRealtime()
       val history=samples.getOrPut(id){ArrayDeque<Pair<Long,Long>>()}
       if(history.isNotEmpty() && done<history.last().first)history.clear()
       history.addLast(Pair(done,now))
       while(history.size>2 && now-history.first().second>8000L)history.removeFirst()
       val oldest=history.first()
       val elapsed=now-oldest.second
       val speed=if(status==DownloadManager.STATUS_RUNNING && elapsed>=1000L)
        ((done-oldest.first).coerceAtLeast(0).toDouble()*1000.0/elapsed).toLong() else 0L
       val percent=if(total>0)(done*100/total).toInt().coerceIn(0,100) else 0
       val state=when(status){
        DownloadManager.STATUS_SUCCESSFUL->"Completed"
        DownloadManager.STATUS_FAILED->"Failed"
        DownloadManager.STATUS_PAUSED->"Paused"
        DownloadManager.STATUS_PENDING->"Waiting"
        else->"Downloading"
       }
       val eta=if(speed>0&&total>done)" • ~${duration((total-done)/speed)} remaining" else ""
       val isHistory=status==DownloadManager.STATUS_SUCCESSFUL||status==DownloadManager.STATUS_FAILED
       if(isHistory&&!historyHeader){
        historyHeader=true
        list.addView(TextView(this@MainActivity).apply{text="HISTORY";textSize=13f;setTextColor(0xff00E5EE.toInt());setPadding(8.dp(),16.dp(),8.dp(),10.dp())})
       }else if(!isHistory&&!activeHeader){
        activeHeader=true
        list.addView(TextView(this@MainActivity).apply{text="ACTIVE DOWNLOADS";textSize=13f;setTextColor(0xff00E5EE.toInt());setPadding(8.dp(),10.dp(),8.dp(),10.dp())})
       }
       val card=LinearLayout(this@MainActivity).apply{
        orientation=LinearLayout.VERTICAL
        setPadding(16.dp(),14.dp(),16.dp(),14.dp())
        background=rounded(0xff151E21.toInt(),18)
       }
       card.addView(TextView(this@MainActivity).apply{text=info.first;setTextColor(Color.WHITE);textSize=16f;maxLines=2})
       card.addView(TextView(this@MainActivity).apply{
        text="$state • ${pretty(done)} / ${pretty(total)}"
        setTextColor(0xffADBDC1.toInt());textSize=13f
       })
       if(status==DownloadManager.STATUS_RUNNING||status==DownloadManager.STATUS_PENDING||status==DownloadManager.STATUS_PAUSED){
        card.addView(ProgressBar(this@MainActivity,null,android.R.attr.progressBarStyleHorizontal).apply{
         isIndeterminate=total<=0;progress=percent;max=100
        })
        card.addView(TextView(this@MainActivity).apply{
         text=if(speed>0)"${pretty(speed)}/s$eta" else "Calculating speed…"
         setTextColor(0xffADBDC1.toInt());textSize=12f
        })
       }
       val actions=LinearLayout(this@MainActivity).apply{orientation=LinearLayout.HORIZONTAL}
       if(status==DownloadManager.STATUS_SUCCESSFUL){
        actions.addView(TextView(this@MainActivity).apply{text=if(isVideoFile(info.first,""))"▶ Play" else "Open";styleDownloadAction(this,1);setOnClickListener{
         val uri=downloadManager.getUriForDownloadedFile(id)
         if(uri!=null)openDownloadedFile(uri,info.first,c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_MEDIA_TYPE))?:"*/*")
        }})
       }
       actions.addView(TextView(this@MainActivity).apply{text="Remove";styleDownloadAction(this,2);setOnClickListener{
        downloadManager.remove(id);downloads.remove(id)
        getSharedPreferences("app_downloads",MODE_PRIVATE).edit().remove(id.toString()).apply()
        dialog.dismiss();showDownloads()
       }})
       for(i in 0 until actions.childCount){
      actions.getChildAt(i).layoutParams=LinearLayout.LayoutParams(-2,44.dp()).apply{marginEnd=9.dp()}
     }
     card.addView(actions)
       list.addView(card,LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=10.dp()})
      }
     }
    }
    uiHandler.postDelayed(this,1000)
   }
  }
  dialog.setOnDismissListener{uiHandler.removeCallbacks(refresh)}
  dialog.show()
  dialog.window?.setLayout(-1,-1)
  dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
  refresh.run()
 }
 private fun showSettings(){
  val prefs=getSharedPreferences("web_settings",MODE_PRIVATE)
  val panel=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(18.dp(),18.dp(),18.dp(),18.dp());setBackgroundColor(0xff000000.toInt())}
  val scroll=ScrollView(this)
  val body=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  scroll.addView(body)
  val dialog=AlertDialog.Builder(this).setView(panel).create()
  panel.addView(TextView(this).apply{text="‹    Settings";textSize=24f;setTextColor(Color.WHITE);setPadding(4.dp(),4.dp(),4.dp(),20.dp());setOnClickListener{dialog.dismiss()}})
  panel.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
  fun section(title:String){
   body.addView(TextView(this).apply{text=title;textSize=18f;setTextColor(0xff00E5EE.toInt());setPadding(8.dp(),20.dp(),8.dp(),10.dp())})
  }
  fun row(title:String,description:String="",action:()->Unit){
   body.addView(TextView(this).apply{
    text=title+if(description.isNotBlank())"\n"+description else ""
    textSize=15f;setTextColor(Color.WHITE);setPadding(16.dp(),15.dp(),16.dp(),15.dp())
    background=rounded(0xff151E21.toInt(),16);setOnClickListener{action()}
   },LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=8.dp()})
  }
  fun toggle(label:String,key:String,default:Boolean=false){
   body.addView(Switch(this).apply{
    text=label;textSize=15f;setTextColor(Color.WHITE);isChecked=prefs.getBoolean(key,default)
    setPadding(14.dp(),12.dp(),14.dp(),12.dp());background=rounded(0xff151E21.toInt(),16)
    setOnCheckedChangeListener{_,checked->prefs.edit().putBoolean(key,checked).apply()}
   },LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=8.dp()})
  }
  section("Appearance")
  row("Theme","AMOLED Black / Light / System"){
   val options=arrayOf("AMOLED Black","Light","System")
   AlertDialog.Builder(this).setItems(options){_,i->prefs.edit().putInt("theme",i).apply();Toast.makeText(this,"Theme preference saved",Toast.LENGTH_SHORT).show()}.show()
  }
  row("Accent color","Cyan / Blue / Purple"){
   AlertDialog.Builder(this).setItems(arrayOf("Cyan","Blue","Purple")){_,i->prefs.edit().putInt("accent",i).apply()}.show()
  }
  row("Website text size","75% to 150%"){
   val sizes=intArrayOf(75,90,100,110,125,150)
   AlertDialog.Builder(this).setItems(sizes.map{"$it%"}.toTypedArray()){_,i->
    prefs.edit().putInt("text_scale",sizes[i]).apply()
    tabs.forEach{it.settings.textZoom=sizes[i]}
   }.show()
  }
  section("Browsing")
  toggle("Restore previous tabs","restore_tabs",true)
  toggle("Open links in background","background_tabs",true)
  toggle("Desktop mode","desktop")
  row("Homepage","Choose URL for new tabs"){
   val input=EditText(this).apply{setSingleLine();setText(prefs.getString("homepage",home))}
   AlertDialog.Builder(this).setTitle("Homepage").setView(input).setPositiveButton("Save"){_,_->
    val u=input.text.toString().trim()
    if(u.startsWith("https://")||u.startsWith("http://"))prefs.edit().putString("homepage",u).apply()
   }.setNegativeButton("Cancel",null).show()
  }
  section("Downloads & Storage")
  row("Download history","Active, completed and failed downloads"){dialog.dismiss();showDownloads()}
  toggle("Wi-Fi only downloads","wifi_only")
  toggle("Download notifications","download_notifications",true)
  row("Download location","Android Downloads folder"){}
  row("Storage usage","Android app storage settings"){
   startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:$packageName")))
  }
  row("Clear download history"){
   AlertDialog.Builder(this).setTitle("Clear download history?").setPositiveButton("Clear"){_,_->
    downloads.clear();getSharedPreferences("app_downloads",MODE_PRIVATE).edit().clear().apply()
   }.setNegativeButton("Cancel",null).show()
  }
  section("Privacy & Security")
  row("Website permissions","Camera, microphone and location"){
   startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:$packageName")))
  }
  row("Clear cookies"){
   CookieManager.getInstance().removeAllCookies(null);CookieManager.getInstance().flush()
  }
  row("Clear browsing history"){tabs.forEach{it.clearHistory()}}
  row("Clear cache"){tabs.forEach{it.clearCache(true)}}
  section("About")
  row("App version",packageManager.getPackageInfo(packageName,0).versionName?:"1.0"){}
  row("Developer","Made by Mohammed Azeem"){}
  row("Website",home){startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(home)))}
  row("Privacy policy","Visit website privacy page"){
   startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(home.trimEnd('/')+"/privacy")))
  }
  dialog.show();dialog.window?.setLayout(-1,-1)
 }

}
'''.replace('__WEB_URL__',url))
# A true foreground service handles downloads after the activity is left or replaced.
service=src/'java/com/webtoapp/template/DownloadService.kt'
service.write_text((Path(__file__).with_name('download_service.kt')).read_text())
player=src/'java/com/webtoapp/template/VideoPlayerActivity.kt'
player.write_text((Path(__file__).with_name('video_player.kt')).read_text())
layout.write_text('''<?xml version="1.0" encoding="utf-8"?><androidx.swiperefreshlayout.widget.SwipeRefreshLayout xmlns:android="http://schemas.android.com/apk/res/android" android:id="@+id/swipeRefresh" android:layout_width="match_parent" android:layout_height="match_parent"><WebView android:id="@+id/webView" android:layout_width="match_parent" android:layout_height="match_parent" /></androidx.swiperefreshlayout.widget.SwipeRefreshLayout>''')
s=manifest.read_text()
if 'android.permission.FOREGROUND_SERVICE_DATA_SYNC' not in s:
    s=s.replace('<uses-permission android:name="android.permission.INTERNET" />',
     '<uses-permission android:name="android.permission.INTERNET" />\n'
     '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />\n'
     '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />\n'
     '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />')
if 'android:name=".VideoPlayerActivity"' not in s:
    s=s.replace('</application>','<activity android:name=".VideoPlayerActivity" '
     'android:exported="false" android:supportsPictureInPicture="true" '
     'android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation|uiMode" />\n    </application>')
if 'android:name=".DownloadService"' not in s:
    s=s.replace('</application>','<service android:name=".DownloadService" android:exported="false" '
     'android:foregroundServiceType="dataSync" />\n    </application>')
s=re.sub(r'android:label="[^"]*"',f'android:label="{name}"',s); s=re.sub(r'android:screenOrientation="[^"]*"',f'android:screenOrientation="{orientation}"',s)
# Cropper is needed by the builder only, not by generated website apps.
s=re.sub(r'\s*<activity android:name="com\.canhub\.cropper\.CropImageActivity"[^>]*/>','',s)
manifest.write_text(s)
if a.icon_base64:
    try:
        icon_xml=src/'res/drawable/app_icon.xml'
        if icon_xml.exists(): icon_xml.unlink()
        (src/'res/drawable/app_icon.jpg').write_bytes(base64.b64decode(a.icon_base64))
    except Exception as e:
        print("Custom icon could not be decoded; using default icon:",e)
s=gradle.read_text(); s=re.sub(r'applicationId = "[^"]*"',f'applicationId = "{pkg}"',s); gradle.write_text(s)
