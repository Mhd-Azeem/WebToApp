import argparse,re
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--url',required=True); p.add_argument('--name',required=True); p.add_argument('--package',required=True); p.add_argument('--orientation',choices=['auto','portrait','landscape'],default='auto'); a=p.parse_args()
root=Path(__file__).resolve().parents[1]/'android-template'; src=root/'app/src/main'; main=src/'java/com/webtoapp/template/MainActivity.kt'; layout=src/'res/layout/activity_main.xml'; manifest=src/'AndroidManifest.xml'; gradle=root/'app/build.gradle.kts'
url=a.url.replace('"',''); name=a.name.replace('"',''); pkg=a.package; orientation={'auto':'unspecified','portrait':'portrait','landscape':'landscape'}[a.orientation]
main.write_text(f'''package com.webtoapp.template
import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
class MainActivity:AppCompatActivity(){{
 private lateinit var webView:WebView
 @SuppressLint("SetJavaScriptEnabled") override fun onCreate(savedInstanceState:Bundle?){{super.onCreate(savedInstanceState);setContentView(R.layout.activity_main);webView=findViewById(R.id.webView);val swipe=findViewById<SwipeRefreshLayout>(R.id.swipeRefresh);CookieManager.getInstance().apply{{setAcceptCookie(true);setAcceptThirdPartyCookies(webView,true)}};webView.settings.apply{{javaScriptEnabled=true;domStorageEnabled=true;databaseEnabled=true;useWideViewPort=true;loadWithOverviewMode=true;mediaPlaybackRequiresUserGesture=false}};webView.webViewClient=object:WebViewClient(){{override fun shouldOverrideUrlLoading(v:WebView,r:WebResourceRequest)=false;override fun onPageFinished(v:WebView,u:String){{swipe.isRefreshing=false}}}};swipe.setOnRefreshListener{{webView.reload()}};onBackPressedDispatcher.addCallback(this,object:OnBackPressedCallback(true){{override fun handleOnBackPressed(){{if(webView.canGoBack())webView.goBack() else finish()}}}});if(savedInstanceState==null)webView.loadUrl("{url}") else webView.restoreState(savedInstanceState)}}
 override fun onSaveInstanceState(outState:Bundle){{webView.saveState(outState);super.onSaveInstanceState(outState)}}
}}
''')
layout.write_text('''<?xml version="1.0" encoding="utf-8"?><androidx.swiperefreshlayout.widget.SwipeRefreshLayout xmlns:android="http://schemas.android.com/apk/res/android" android:id="@+id/swipeRefresh" android:layout_width="match_parent" android:layout_height="match_parent"><WebView android:id="@+id/webView" android:layout_width="match_parent" android:layout_height="match_parent" /></androidx.swiperefreshlayout.widget.SwipeRefreshLayout>''')
s=manifest.read_text(); s=re.sub(r'android:label="[^"]*"',f'android:label="{name}"',s); s=re.sub(r'android:screenOrientation="[^"]*"',f'android:screenOrientation="{orientation}"',s); manifest.write_text(s)
s=gradle.read_text(); s=re.sub(r'applicationId = "[^"]*"',f'applicationId = "{pkg}"',s); gradle.write_text(s)
