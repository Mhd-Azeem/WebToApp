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
import android.os.SystemClock
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
 private val tabs=ArrayList<WebView>()
 private var active=0
 private val home="__WEB_URL__"
 private val downloads=linkedMapOf<Long,Pair<String,Long>>()
 private val downloadManager by lazy{getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager}
 private val uiHandler=android.os.Handler(android.os.Looper.getMainLooper())
 @SuppressLint("SetJavaScriptEnabled")
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  window.statusBarColor=Color.rgb(7,22,45)
  window.navigationBarColor=Color.rgb(7,22,45)
  window.decorView.systemUiVisibility=0
  window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN or WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
  val saved=getSharedPreferences("app_downloads",MODE_PRIVATE)
  saved.all.forEach{(key,value)->key.toLongOrNull()?.let{id->if(value is String)downloads[id]=Pair(value,SystemClock.elapsedRealtime())}}
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  val bar=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;gravity=android.view.Gravity.CENTER_VERTICAL;setPadding(10,5,10,5);setBackgroundColor(0xff102C58.toInt());minimumHeight=52.dp()}
  tabButton=TextView(this).apply{text="▣ 1";textSize=17f;setTextColor(-1);setPadding(18,12,18,12);setOnClickListener{showTabs()}}
  val menu=TextView(this).apply{text="⋮";textSize=27f;setTextColor(-1);setPadding(24,12,24,12);setOnClickListener{showMenu()}}
  bar.addView(tabButton,LinearLayout.LayoutParams(0,-2,1f));bar.addView(menu)
  container=FrameLayout(this)
  root.setBackgroundColor(0xff08172F.toInt())
  root.addView(bar);root.addView(container,LinearLayout.LayoutParams(-1,0,1f))
  setContentView(root)
  openTab(home,true)
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
  val scroll=ScrollView(this)
  val list=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(20,20,20,20)}
  scroll.addView(list)
  val dialog=AlertDialog.Builder(this).setTitle("Tabs (${tabs.size})").setView(scroll).setPositiveButton("New tab"){_,_->openTab(home,true)}.setNegativeButton("Close",null).create()
  tabs.toList().forEachIndexed{index,w->
   val row=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;setPadding(12,12,12,12)}
   val title=TextView(this).apply{
    text="${if(index==active)"● " else ""}${w.title?:w.url?:"New tab"}\n${w.url?:""}"
    maxLines=3;textSize=14f;setPadding(12,24,12,24)
    setOnClickListener{activate(index);dialog.dismiss()}
   }
   val close=Button(this).apply{text="×";setOnClickListener{closeTab(index);dialog.dismiss();showTabs()}}
   row.addView(title,LinearLayout.LayoutParams(0,-2,1f));row.addView(close)
   list.addView(row)
  }
  dialog.show()
 }
 private fun Int.dp()=(this*resources.displayMetrics.density).toInt()
 private fun pretty(bytes:Long):String=when{
  bytes<0->"Unknown"
  bytes<1024->"$bytes B"
  bytes<1048576->String.format("%.1f KB",bytes/1024.0)
  bytes<1073741824->String.format("%.1f MB",bytes/1048576.0)
  else->String.format("%.2f GB",bytes/1073741824.0)
 }
 private fun showDownloads(){
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(0xff0B1B35.toInt());setPadding(16.dp(),12.dp(),16.dp(),12.dp())}
  val heading=TextView(this).apply{text="Downloads";setTextColor(Color.WHITE);textSize=23f;setPadding(6.dp(),4.dp(),6.dp(),12.dp())}
  val scroll=ScrollView(this)
  val list=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  scroll.addView(list)
  root.addView(heading)
  root.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
  val dialog=AlertDialog.Builder(this).setView(root).setPositiveButton("Done",null).create()
  var previous=mutableMapOf<Long,Pair<Long,Long>>()
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
       val old=previous[id]
       val speed=if(old!=null && now>old.second) ((done-old.first).coerceAtLeast(0)*1000/(now-old.second)) else 0L
       previous[id]=Pair(done,now)
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
        setBackgroundColor(0xff19345A.toInt())
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
  dialog.window?.setLayout(-1,(resources.displayMetrics.heightPixels*0.83).toInt())
  refresh.run()
 }
 private fun showMenu(){
  val choices=arrayOf("Tabs","New tab","Downloads","Refresh","Share","Settings")
  AlertDialog.Builder(this).setItems(choices){_,which->when(which){
   0->showTabs()
   1->openTab(home,true)
   2->showDownloads()
   3->tabs.getOrNull(active)?.reload()
   4->{val intent=Intent(Intent.ACTION_SEND).apply{type="text/plain";putExtra(Intent.EXTRA_TEXT,tabs.getOrNull(active)?.url?:home)};startActivity(Intent.createChooser(intent,"Share page"))}
   5->AlertDialog.Builder(this).setTitle("Settings").setMessage("Tabs open in the background. Downloads are saved to the Downloads folder.").setPositiveButton("OK",null).show()
  }}.show()
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
