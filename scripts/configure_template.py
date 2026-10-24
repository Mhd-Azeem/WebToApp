import argparse,re,base64
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--url',required=True); p.add_argument('--name',required=True); p.add_argument('--package',required=True)
p.add_argument('--orientation',choices=['auto','portrait','landscape'],default='auto')
p.add_argument('--icon-base64',default='')
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
import android.graphics.drawable.GradientDrawable
import android.os.SystemClock
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

class MainActivity:AppCompatActivity(){
 private lateinit var container:FrameLayout
 private lateinit var tabButton:TextView
 private lateinit var downloadButton:TextView
 private lateinit var topBar:LinearLayout
 private val tabs=ArrayList<WebView>()
 private var active=0
 private val home="__WEB_URL__"
 private val downloads=linkedMapOf<Long,Pair<String,Long>>()
 private val downloadManager by lazy{getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager}
 private val uiHandler=android.os.Handler(android.os.Looper.getMainLooper())
 @SuppressLint("SetJavaScriptEnabled")
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  WindowCompat.setDecorFitsSystemWindows(window,false)
  window.statusBarColor=Color.rgb(7,22,45)
  window.navigationBarColor=Color.rgb(7,22,45)
  window.decorView.systemUiVisibility=0
  window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN or WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
  val saved=getSharedPreferences("app_downloads",MODE_PRIVATE)
  saved.all.forEach{(key,value)->key.toLongOrNull()?.let{id->if(value is String)downloads[id]=Pair(value,SystemClock.elapsedRealtime())}}
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  val overlay=FrameLayout(this)
  val controls=LinearLayout(this).apply{
   orientation=LinearLayout.HORIZONTAL
   gravity=android.view.Gravity.CENTER_VERTICAL
   setPadding(6.dp(),5.dp(),6.dp(),5.dp())
   background=rounded(0xff102C58.toInt(),24,0xff2864A8.toInt())
   elevation=8.dp().toFloat()
  }
  topBar=controls
  tabButton=TextView(this).apply{text="▢ 1";textSize=15f;setTextColor(Color.WHITE);setPadding(12.dp(),8.dp(),12.dp(),8.dp());setOnClickListener{showTabs()}}
  downloadButton=TextView(this).apply{text="↓";textSize=21f;setTextColor(0xff35C9FF.toInt());setPadding(12.dp(),8.dp(),12.dp(),8.dp());visibility=View.GONE;setOnClickListener{showDownloads()}}
  val menu=TextView(this).apply{text="⋮";textSize=23f;setTextColor(Color.WHITE);setPadding(12.dp(),8.dp(),12.dp(),8.dp());setOnClickListener{showMenu()}}
  controls.addView(tabButton);controls.addView(downloadButton);controls.addView(menu)
  container=FrameLayout(this)
  root.setBackgroundColor(0xff08172F.toInt())
  overlay.addView(container,FrameLayout.LayoutParams(-1,-1))
  overlay.addView(controls,FrameLayout.LayoutParams(-2,-2,android.view.Gravity.TOP or android.view.Gravity.END).apply{
   topMargin=12.dp();rightMargin=12.dp()
  })
  root.addView(overlay,LinearLayout.LayoutParams(-1,0,1f))
  setContentView(root)
  ViewCompat.setOnApplyWindowInsetsListener(root){view,insets->
   val bars=insets.getInsets(WindowInsetsCompat.Type.systemBars())
   view.setPadding(bars.left,bars.top,bars.right,bars.bottom)
   insets
  }
  openTab(home,true)
  monitorDownloads()
  onBackPressedDispatcher.addCallback(this,object:OnBackPressedCallback(true){override fun handleOnBackPressed(){
   val current=tabs.getOrNull(active)
   if(current?.canGoBack()==true)current.goBack()
   else if(tabs.size>1)closeTab(active)
   else finish()
  }})
 }
 @SuppressLint("SetJavaScriptEnabled")
 private fun createWebView():WebView{
  val w=WebView(this)
  w.settings.apply{javaScriptEnabled=true;domStorageEnabled=true;databaseEnabled=true;setSupportMultipleWindows(true);javaScriptCanOpenWindowsAutomatically=true;useWideViewPort=true;loadWithOverviewMode=true;mediaPlaybackRequiresUserGesture=false}
  CookieManager.getInstance().apply{setAcceptCookie(true);setAcceptThirdPartyCookies(w,true)}
  w.webViewClient=object:WebViewClient(){
   override fun shouldOverrideUrlLoading(view:WebView,request:WebResourceRequest):Boolean{
    val uri=request.url
    if(uri.scheme!="http"&&uri.scheme!="https"){runCatching{startActivity(Intent(Intent.ACTION_VIEW,uri))};return true}
    return false
   }
  }
  w.webChromeClient=object:WebChromeClient(){
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
    val filename=URLUtil.guessFileName(url,disposition,mime)
    val request=DownloadManager.Request(Uri.parse(url)).setTitle(filename).setMimeType(mime)
     .setDescription("Downloading file").setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
     .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS,filename)
    request.addRequestHeader("User-Agent",agent?:w.settings.userAgentString)
    CookieManager.getInstance().getCookie(url)?.let{request.addRequestHeader("Cookie",it)}
    val id=downloadManager.enqueue(request)
    downloads[id]=Pair(filename,SystemClock.elapsedRealtime())
    downloadButton.visibility=View.VISIBLE
    getSharedPreferences("app_downloads",MODE_PRIVATE).edit().putString(id.toString(),filename).apply()
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
  active=index;container.removeAllViews()
  val w=tabs[index];(w.parent as? android.view.ViewGroup)?.removeView(w)
  container.addView(w,FrameLayout.LayoutParams(-1,-1));updateCount()
 }
 private fun updateCount(){tabButton.text="▣ ${tabs.size}"}
 private fun closeTab(index:Int){
  if(index !in tabs.indices)return
  val w=tabs.removeAt(index)
  (w.parent as? android.view.ViewGroup)?.removeView(w);w.destroy()
  if(tabs.isEmpty()){openTab(home,true);return}
  if(index<active)active--
  if(index==active||active>=tabs.size)active=active.coerceAtMost(tabs.lastIndex)
  activate(active)
 }
 private fun showTabs(){
  val panel=LinearLayout(this).apply{
   orientation=LinearLayout.VERTICAL;setPadding(18.dp(),18.dp(),18.dp(),18.dp())
   background=rounded(0xff0B1B35.toInt(),24)
  }
  val dialog=AlertDialog.Builder(this).setView(panel).create()
  val header=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL}
  header.addView(TextView(this).apply{text="Your tabs  ·  ${tabs.size}";textSize=21f;setTextColor(Color.WHITE)},LinearLayout.LayoutParams(0,-2,1f))
  header.addView(TextView(this).apply{
   text="+ New";textSize=15f;setTextColor(0xff46C6FF.toInt());setPadding(12.dp(),10.dp(),12.dp(),10.dp())
   setOnClickListener{openTab(home,true);dialog.dismiss()}
  })
  panel.addView(header)
  val scroll=ScrollView(this)
  val list=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(0,12.dp(),0,0)}
  scroll.addView(list)
  panel.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
  tabs.toList().forEachIndexed{index,w->
   val row=LinearLayout(this).apply{
    orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL
    setPadding(14.dp(),12.dp(),10.dp(),12.dp())
    background=rounded(if(index==active)0xff194B80.toInt() else 0xff152F52.toInt(),18)
   }
   val title=TextView(this).apply{
    text="${if(index==active)"●  " else ""}${w.title?:w.url?:"New tab"}\n${w.url?:""}"
    setTextColor(Color.WHITE);maxLines=2;ellipsize=android.text.TextUtils.TruncateAt.END;textSize=14f
    setOnClickListener{activate(index);dialog.dismiss()}
   }
   val close=TextView(this).apply{text="×";textSize=23f;setTextColor(0xffA9C5E9.toInt());setPadding(12.dp(),5.dp(),12.dp(),5.dp());setOnClickListener{closeTab(index);dialog.dismiss();showTabs()}}
   row.addView(title,LinearLayout.LayoutParams(0,-2,1f));row.addView(close)
   list.addView(row,LinearLayout.LayoutParams(-1,-2).apply{bottomMargin=10.dp()})
  }
  dialog.show()
  dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
  dialog.window?.setLayout(-1,(resources.displayMetrics.heightPixels*0.78).toInt())
 }
 private fun rounded(fill:Int,radius:Int,stroke:Int=0):GradientDrawable=
  GradientDrawable().apply{setColor(fill);cornerRadius=radius.dp().toFloat();if(stroke!=0)setStroke(1.dp(),stroke)}
 private fun Int.dp()=(this*resources.displayMetrics.density).toInt()
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
    var activeDownload=false
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
  dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(0xff00AFFF.toInt())
  dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(0xff00AFFF.toInt())
 }
 private fun showDownloads(){
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(0xff0B1B35.toInt());setPadding(16.dp(),12.dp(),16.dp(),12.dp())}
  val heading=TextView(this).apply{text="Downloads";setTextColor(Color.WHITE);textSize=23f;setPadding(6.dp(),4.dp(),6.dp(),12.dp())}
  val scroll=ScrollView(this)
  val list=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  scroll.addView(list)
  root.addView(heading)
  root.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
  val dialog=AlertDialog.Builder(this,androidx.appcompat.R.style.Theme_AppCompat_Dialog).setView(root).create()
  heading.text="‹     Downloads"
  heading.setOnClickListener{dialog.dismiss()}
  val samples=mutableMapOf<Long,ArrayDeque<Pair<Long,Long>>>()
  val refresh=object:Runnable{
   override fun run(){
    if(!dialog.isShowing)return
    list.removeAllViews()
    if(downloads.isEmpty()){
     list.addView(TextView(this@MainActivity).apply{text="No downloads yet";setTextColor(Color.LTGRAY);textSize=16f;setPadding(12.dp(),28.dp(),12.dp(),28.dp())})
    }
    for((id,info) in downloads.toList().asReversed()){
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
       val eta=if(speed>0&&total>done)" • ~${(total-done)/speed}s left" else ""
       val card=LinearLayout(this@MainActivity).apply{
        orientation=LinearLayout.VERTICAL
        setPadding(16.dp(),14.dp(),16.dp(),14.dp())
        background=rounded(0xff19345A.toInt(),18)
       }
       card.addView(TextView(this@MainActivity).apply{text=info.first;setTextColor(Color.WHITE);textSize=16f;maxLines=2})
       card.addView(TextView(this@MainActivity).apply{
        text="$state • ${pretty(done)} / ${pretty(total)}"
        setTextColor(0xffB8CDEA.toInt());textSize=13f
       })
       if(status==DownloadManager.STATUS_RUNNING||status==DownloadManager.STATUS_PENDING||status==DownloadManager.STATUS_PAUSED){
        card.addView(ProgressBar(this@MainActivity,null,android.R.attr.progressBarStyleHorizontal).apply{
         isIndeterminate=total<=0;progress=percent;max=100
        })
        card.addView(TextView(this@MainActivity).apply{
         text=if(speed>0)"${pretty(speed)}/s$eta" else "Calculating speed…"
         setTextColor(0xffB8CDEA.toInt());textSize=12f
        })
       }
       val actions=LinearLayout(this@MainActivity).apply{orientation=LinearLayout.HORIZONTAL}
       if(status==DownloadManager.STATUS_SUCCESSFUL){
        actions.addView(Button(this@MainActivity).apply{text="Open";setOnClickListener{
         val uri=downloadManager.getUriForDownloadedFile(id)
         if(uri!=null)runCatching{startActivity(Intent(Intent.ACTION_VIEW).apply{setDataAndType(uri,c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_MEDIA_TYPE))?:"*/*");addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)})}.onFailure{Toast.makeText(this@MainActivity,"No app can open this file",Toast.LENGTH_SHORT).show()}
        }})
       }
       actions.addView(Button(this@MainActivity).apply{text="Remove";setOnClickListener{
        downloadManager.remove(id);downloads.remove(id)
        getSharedPreferences("app_downloads",MODE_PRIVATE).edit().remove(id.toString()).apply()
        dialog.dismiss();showDownloads()
       }})
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
 private fun showMenu(){
  val choices=arrayOf("Tabs","New tab","Downloads","Refresh","Share","Settings")
  val menuView=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(12.dp(),12.dp(),12.dp(),12.dp());background=rounded(0xff102C58.toInt(),18)}
  val popup=AlertDialog.Builder(this).setView(menuView).create()
  choices.forEachIndexed{which,choice->
   menuView.addView(TextView(this@MainActivity).apply{text=choice;textSize=17f;setTextColor(Color.WHITE);setPadding(20.dp(),15.dp(),20.dp(),15.dp());setOnClickListener{popup.dismiss();when(which){
   0->showTabs()
   1->openTab(home,true)
   2->showDownloads()
   3->tabs.getOrNull(active)?.reload()
   4->{val intent=Intent(Intent.ACTION_SEND).apply{type="text/plain";putExtra(Intent.EXTRA_TEXT,tabs.getOrNull(active)?.url?:home)};startActivity(Intent.createChooser(intent,"Share page"))}
   5->AlertDialog.Builder(this@MainActivity).setTitle("Settings").setMessage("Tabs open in the background. Downloads are saved to the Downloads folder.").setPositiveButton("OK",null).show()
  }}})
  }
  popup.show()
  popup.window?.setBackgroundDrawableResource(android.R.color.transparent)
 }
}
'''.replace('__WEB_URL__',url))
layout.write_text('''<?xml version="1.0" encoding="utf-8"?><androidx.swiperefreshlayout.widget.SwipeRefreshLayout xmlns:android="http://schemas.android.com/apk/res/android" android:id="@+id/swipeRefresh" android:layout_width="match_parent" android:layout_height="match_parent"><WebView android:id="@+id/webView" android:layout_width="match_parent" android:layout_height="match_parent" /></androidx.swiperefreshlayout.widget.SwipeRefreshLayout>''')
s=manifest.read_text(); s=re.sub(r'android:label="[^"]*"',f'android:label="{name}"',s); s=re.sub(r'android:screenOrientation="[^"]*"',f'android:screenOrientation="{orientation}"',s)
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
