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
 @SuppressLint("SetJavaScriptEnabled")
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState)
  val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
  val bar=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;setBackgroundColor(0xff17243b.toInt())}
  tabButton=TextView(this).apply{text="1 ▣";textSize=18f;setTextColor(-1);setPadding(24,18,24,18);setOnClickListener{showTabs()}}
  val menu=TextView(this).apply{text="⋮";textSize=26f;setTextColor(-1);setPadding(28,12,28,12);setOnClickListener{showMenu()}}
  bar.addView(tabButton,LinearLayout.LayoutParams(0,-2,1f));bar.addView(menu)
  container=FrameLayout(this)
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
    (getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
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
 private fun updateCount(){tabButton.text="${tabs.size} ▣"}
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
 private fun showMenu(){
  val choices=arrayOf("Tabs","New tab","Downloads","Refresh","Share","Settings")
  AlertDialog.Builder(this).setItems(choices){_,which->when(which){
   0->showTabs()
   1->openTab(home,true)
   2->startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS))
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
