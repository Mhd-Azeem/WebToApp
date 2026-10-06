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
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.webkit.CookieManager
import android.webkit.URLUtil
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout

class MainActivity:AppCompatActivity(){
 private lateinit var webView:WebView
 @SuppressLint("SetJavaScriptEnabled")
 override fun onCreate(savedInstanceState:Bundle?){
  super.onCreate(savedInstanceState);setContentView(R.layout.activity_main)
  webView=findViewById(R.id.webView);val swipe=findViewById<SwipeRefreshLayout>(R.id.swipeRefresh)
  CookieManager.getInstance().apply{setAcceptCookie(true);setAcceptThirdPartyCookies(webView,true)}
  webView.settings.apply{javaScriptEnabled=true;domStorageEnabled=true;databaseEnabled=true;useWideViewPort=true;loadWithOverviewMode=true;mediaPlaybackRequiresUserGesture=false}
  webView.webViewClient=object:WebViewClient(){
   override fun shouldOverrideUrlLoading(v:WebView,r:WebResourceRequest)=false
   override fun onPageFinished(v:WebView,u:String){swipe.isRefreshing=false}
  }
  webView.setDownloadListener { downloadUrl, userAgent, contentDisposition, mimeType, _ ->
   try {
    val fileName=URLUtil.guessFileName(downloadUrl,contentDisposition,mimeType)
    val request=DownloadManager.Request(Uri.parse(downloadUrl))
     .setMimeType(mimeType)
     .addRequestHeader("User-Agent",userAgent ?: webView.settings.userAgentString)
     .setTitle(fileName)
     .setDescription("Downloading file…")
     .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
     .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS,fileName)
     .setAllowedOverMetered(true)
     .setAllowedOverRoaming(true)
    CookieManager.getInstance().getCookie(downloadUrl)?.let { request.addRequestHeader("Cookie",it) }
    (getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
    Toast.makeText(this,"Download started: "+fileName,Toast.LENGTH_LONG).show()
   } catch(e:Exception){ Toast.makeText(this,"Download could not start",Toast.LENGTH_LONG).show() }
  }
  swipe.setOnRefreshListener{webView.reload()}
  onBackPressedDispatcher.addCallback(this,object:OnBackPressedCallback(true){override fun handleOnBackPressed(){if(webView.canGoBack())webView.goBack() else finish()}})
  if(savedInstanceState==null)webView.loadUrl("__WEB_URL__") else webView.restoreState(savedInstanceState)
 }
 override fun onSaveInstanceState(outState:Bundle){webView.saveState(outState);super.onSaveInstanceState(outState)}
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
