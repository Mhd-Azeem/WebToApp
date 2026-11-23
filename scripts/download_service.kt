package com.webtoapp.template

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.os.SystemClock
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

/**
 * Downloads live independently of MainActivity and its WebViews.
 * While active, the dataSync foreground service keeps downloading when users
 * change tabs, lock the screen or switch apps. Android may still enforce its
 * foreground-service and network limits; incomplete files can be resumed.
 */
class DownloadService : Service() {
 companion object {
  const val ACTION_START = "com.webtoapp.template.START_TRANSFER"
  const val ACTION_PAUSE = "com.webtoapp.template.PAUSE_TRANSFER"
  const val ACTION_REMOVE = "com.webtoapp.template.REMOVE_TRANSFER"
  const val EXTRA_ID = "transfer_id"
  private const val CHANNEL = "webtoapp_background_downloads"
  private const val NOTIFICATION_ID = 2601
 }
 private data class Task(val id: Long) {
  @Volatile var cancelled = false
  @Volatile var removed = false
  @Volatile var connection: HttpURLConnection? = null
 }
 private val running = ConcurrentHashMap<Long, Task>()
 private val metadata by lazy { getSharedPreferences("resumable_transfers", MODE_PRIVATE) }
 private val statuses by lazy { getSharedPreferences("transfer_status", MODE_PRIVATE) }
 private val manager by lazy { getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager }
 @Volatile private var foreground = false
 @Volatile private var lastNotification = 0L

 override fun onBind(intent: Intent?): IBinder? = null

 override fun onCreate() {
  super.onCreate()
  if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
   manager.createNotificationChannel(NotificationChannel(
    CHANNEL, "Background downloads", NotificationManager.IMPORTANCE_LOW
   ).apply { description = "Shows download progress while WebToApp is in the background" })
  }
 }

 override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
  val action = intent?.action
  val id = intent?.getLongExtra(EXTRA_ID, -1L) ?: -1L
  when {
   action == ACTION_START && id > 0 -> {
    if(!startForegroundSafely()) {
     saveStatus(id, "Failed: Android blocked background download service")
     stopSelf()
     return START_NOT_STICKY
    }
    startTask(id)
   }
   action == ACTION_PAUSE && id > 0 -> {
    running[id]?.let { it.cancelled = true; it.connection?.disconnect() }
    saveStatusPreservingProgress(id, "Paused")
    stopIfIdle()
   }
   action == ACTION_REMOVE && id > 0 -> {
    running[id]?.let { it.removed = true; it.cancelled = true; it.connection?.disconnect() }
    metadata.edit().remove(id.toString()).apply()
    statuses.edit().remove(id.toString()).apply()
    File(cacheDir, "transfer_" + id + ".part").delete()
    stopIfIdle()
   }
   intent == null -> { // START_STICKY restart after process termination
    val pending = statuses.all.filter { (_, value) ->
     try { val state=JSONObject(value as String).optString("state"); state=="Downloading" || state=="Connecting" || state.startsWith("Retrying") || state=="Saving file" } catch(_:Exception) { false }
    }.keys.mapNotNull { it.toLongOrNull() }
    if(pending.isEmpty()) stopSelf()
    else if(startForegroundSafely()) pending.forEach { startTask(it) }
    else stopSelf()
   }
   else -> stopIfIdle()
  }
  return START_STICKY
 }

 private fun notification(): Notification {
  val open = PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),
   PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val activeIds = running.keys.toList()
  val count = activeIds.size
  val builder=NotificationCompat.Builder(this,CHANNEL)
   .setSmallIcon(android.R.drawable.stat_sys_download)
   .setContentTitle(if(count==1)"Downloading file" else "Background downloads")
   .setContentIntent(open)
   .setOngoing(count>0)
   .setOnlyAlertOnce(true)
   .setPriority(NotificationCompat.PRIORITY_LOW)
   .setCategory(NotificationCompat.CATEGORY_PROGRESS)
  if(count==1) {
   val id=activeIds.first()
   val status=try{JSONObject(statuses.getString(id.toString(),"{}")?:"{}")}catch(_:Exception){JSONObject()}
   val raw=metadata.getString(id.toString(),"")?:""
   val fields=raw.split(31.toChar()).let { if(it.size>=5)it else raw.split(92.toChar().toString()+"u001f") }
   val filename=fields.getOrElse(1){"Download"}
   val done=status.optLong("done",0L)
   val size=status.optLong("size",-1L)
   val state=status.optString("state","Connecting")
   builder.setContentTitle(filename.take(48))
    .setContentText(state+" • "+(done/1024L).toString()+" KB"+if(size>0)" / "+(size/1024L).toString()+" KB" else "")
   if(size>0L)builder.setProgress(100,((done.toDouble()*100)/size).toInt().coerceIn(0,100),false)
   else builder.setProgress(0,0,true)
   val pause=Intent(this,DownloadService::class.java).apply{
    action=ACTION_PAUSE;putExtra(EXTRA_ID,id)
   }
   builder.addAction(android.R.drawable.ic_media_pause,"Pause",
    PendingIntent.getService(this,(id%100000).toInt(),pause,
     PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
  } else {
   builder.setContentText(count.toString()+" active transfers")
  }
  return builder.build()
 }

 @Synchronized private fun startForegroundSafely(): Boolean {
  if(foreground) return true
  return try {
   val notification = notification()
   if(Build.VERSION.SDK_INT >= 29)
    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
   else startForeground(NOTIFICATION_ID, notification)
   foreground = true
   true
  } catch(_: Exception) { false }
 }

 @Synchronized private fun refreshNotification(force: Boolean = false) {
  if(!foreground) return
  val now = SystemClock.elapsedRealtime()
  if(!force && now-lastNotification < 1200L) return
  lastNotification = now
  try { manager.notify(NOTIFICATION_ID, notification()) } catch(_:Exception) {}
 }

 private fun stopIfIdle() {
  if(running.isNotEmpty()) { refreshNotification(true); return }
  if(foreground) {
   if(Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
   else stopForeground(true)
   foreground = false
  }
  stopSelf()
 }

 private fun saveStatus(id: Long, state: String, size: Long = -1, done: Long = 0,
                        speed: Long = 0, uri: String = "") {
  statuses.edit().putString(id.toString(), JSONObject().apply {
   put("state", state); put("size", size); put("done", done)
   put("speed", speed); put("uri", uri)
  }.toString()).apply()
 }

 private fun saveStatusPreservingProgress(id:Long,state:String){
  val previous=try{JSONObject(statuses.getString(id.toString(),"{}")?:"{}")}catch(_:Exception){JSONObject()}
  saveStatus(id,state,previous.optLong("size",-1L),
   File(cacheDir,"transfer_" + id + ".part").length(),0,previous.optString("uri",""))
 }

 private fun isWifiAllowed(): Boolean {
  if(!getSharedPreferences("web_settings", MODE_PRIVATE).getBoolean("wifi_only",false)) return true
  val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  return cm.getNetworkCapabilities(cm.activeNetwork)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)==true
 }

 private fun startTask(id: Long) {
  if(running.containsKey(id)) return
  val raw = metadata.getString(id.toString(), null)
  if(raw == null) { stopIfIdle(); return }
  // Read both current U+001F metadata and older literal "\\u001f" entries.
  val fields = raw.split(31.toChar()).let { separated ->
   if(separated.size >= 5) separated else raw.split(92.toChar().toString() + "u001f")
  }
  if(fields.size < 5) {
   saveStatus(id, "Failed: Invalid download metadata")
   stopIfIdle()
   return
  }
  if(!isWifiAllowed()) {
   saveStatusPreservingProgress(id, "Paused: Wi-Fi required")
   stopIfIdle()
   return
  }
  val task = Task(id)
  if(running.putIfAbsent(id, task) != null) return
  saveStatus(id, "Connecting", done = File(cacheDir,"transfer_" + id + ".part").length())
  refreshNotification(true)
  Thread({
   try {
    val (name,mime,uri) = transfer(task, fields)
    if(!task.cancelled) {
     val file = File(cacheDir, "transfer_" + id + ".part")
     val total = file.length()
     saveStatus(id, "Completed",total,total,0,uri.toString())
     file.delete()
     if(getSharedPreferences("web_settings",MODE_PRIVATE).getBoolean("download_notifications",true)) {
      try {
       manager.notify((id % 100000).toInt()+3000,
        NotificationCompat.Builder(this, CHANNEL)
         .setSmallIcon(android.R.drawable.stat_sys_download_done)
         .setContentTitle("Download complete")
         .setContentText(name)
         .setAutoCancel(true).setContentIntent(PendingIntent.getActivity(
          this, 0, Intent(this, MainActivity::class.java),
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build())
      } catch(_:Exception) {}
     }
    }
   } catch(e: Exception) {
    if(!task.cancelled && !task.removed) {
     val status = statuses.getString(id.toString(),null)
     val old = try { JSONObject(status ?: "{}") } catch(_:Exception) { JSONObject() }
     saveStatus(id,"Failed: " + (e.message ?: "network error"),
      old.optLong("size",-1L),File(cacheDir,"transfer_" + id + ".part").length())
    }
   } finally {
    running.remove(id, task)
    if(running.isEmpty()) stopIfIdle() else refreshNotification(true)
   }
  }, "WebToApp-Download-" + id).start()
 }

 /** Resume partial downloads. If a server ignores Range, restart safely at byte 0. */
 private fun transfer(task:Task, fields:List<String>):Triple<String,String,Uri> {
  val (url,name,mime,agent,cookie)=fields
  val referer=fields.getOrElse(5){""}
  val file = File(cacheDir,"transfer_" + task.id + ".part")
  var attempt = 0
  while(true) {
   if(task.cancelled) throw IOException("Download cancelled")
   attempt++
   var offset = if(file.exists())file.length() else 0L
   var conn = openConnection(url,agent,cookie,referer,offset)
   task.connection = conn
   try {
    var code = conn.responseCode
    if(offset > 0 && (code == 200 || code == 416)) {
     // Some sites don't support byte ranges (or content changed). Restart cleanly.
     conn.disconnect()
     offset=0
     file.delete()
     conn=openConnection(url,agent,cookie,referer,0)
     task.connection=conn
     code=conn.responseCode
    }
    if(code != 200 && code != 206) {
     val explanation=when(code){
      401->"Login required or session expired"
      403->"Access denied by file server; try opening the link again"
      404,410->"File link missing or expired"
      429->"Server rate limit"
      in 500..599->"File server temporarily unavailable"
      else->"Server refused the download"
     }
     throw IOException("HTTP " + code + ": " + explanation)
    }
    val responseType=conn.contentType?.substringBefore(';')?.trim()?.lowercase(java.util.Locale.ROOT).orEmpty()
    val extension=name.substringAfterLast('.',"").lowercase(java.util.Locale.ROOT)
    val expectsBinary=extension in setOf("mp4","mkv","webm","avi","mov","mp3","pdf","zip","rar","apk","7z")
      || mime.startsWith("video/") || mime.startsWith("audio/")
    if(responseType=="text/html" && expectsBinary)
     throw IOException("Server returned an HTML page instead of the requested file; reopen the download link")

    if(code == 206) {
     val range = conn.getHeaderField("Content-Range") ?: ""
     if(!range.startsWith("bytes " + offset + "-")) throw IOException("Server returned wrong resume range")
    }
    val length = conn.contentLengthLong
    val total = if(length >= 0)offset + length else -1L
    var done = offset
    var lastTime = SystemClock.elapsedRealtime()
    var lastBytes = offset
    saveStatus(task.id,"Downloading",total,done)
    RandomAccessFile(file,"rw").use { out ->
     out.setLength(offset);out.seek(offset)
     conn.inputStream.use { input ->
      val buffer=ByteArray(32768)
      while(!task.cancelled) {
       val n=input.read(buffer)
       if(n < 0)break
       out.write(buffer,0,n)
       done+=n
       val now=SystemClock.elapsedRealtime()
       if(now-lastTime>=800) {
        val speed=((done-lastBytes)*1000/(now-lastTime).coerceAtLeast(1L)).coerceAtLeast(0)
        saveStatus(task.id,"Downloading",total,done,speed)
        refreshNotification()
        lastBytes=done;lastTime=now
       }
      }
     }
    }
    if(task.cancelled) throw IOException("Download paused")
    if(total>=0 && done!=total) throw IOException("Incomplete download")
    saveStatus(task.id,"Saving file",total,done)
    val uri=publishFile(file,name,mime)
    return Triple(name,mime,uri)
   } catch(e:Exception) {
    if(task.cancelled)throw e
    if(attempt>=5)throw e
    // Do not endlessly retry auth failures and expired links.
    if(e.message?.startsWith("HTTP 401:")==true ||
       e.message?.startsWith("HTTP 403:")==true ||
       e.message?.startsWith("HTTP 404:")==true ||
       e.message?.startsWith("HTTP 410:")==true ||
       e.message?.contains("HTML page instead")==true)throw e
    val waitMs=(1500L shl (attempt-1)).coerceAtMost(12000L)
    saveStatus(task.id, "Retrying (" + (attempt+1) + "/5) in " + (waitMs/1000L) +
     "s: " + (e.message ?: "network error"),done=file.length())
    var remaining=waitMs
    while(remaining>0 && !task.cancelled){
     val step=remaining.coerceAtMost(500L)
     Thread.sleep(step)
     remaining-=step
    }
    if(task.cancelled)throw IOException("Download paused")
   } finally {
    conn.disconnect()
    task.connection = null
   }
  }
 }

 private fun openConnection(url:String,agent:String,cookie:String,referer:String,offset:Long):HttpURLConnection {
  return (URL(url).openConnection() as HttpURLConnection).apply {
   connectTimeout=20000;readTimeout=20000;instanceFollowRedirects=true
   if(agent.isNotBlank())setRequestProperty("User-Agent",agent)
   if(cookie.isNotBlank())setRequestProperty("Cookie",cookie)
   if(referer.startsWith("https://") || referer.startsWith("http://"))
    setRequestProperty("Referer",referer)
   setRequestProperty("Accept","*/*")
   setRequestProperty("Accept-Encoding","identity")
   if(offset>0)setRequestProperty("Range","bytes=" + offset + "-")
  }
 }

 private fun publishFile(file:File,name:String,mime:String):Uri {
  if(Build.VERSION.SDK_INT >= 29) {
   val values=ContentValues().apply {
    put(MediaStore.Downloads.DISPLAY_NAME,name)
    put(MediaStore.Downloads.MIME_TYPE,mime.ifBlank{"application/octet-stream"})
    put(MediaStore.Downloads.RELATIVE_PATH,Environment.DIRECTORY_DOWNLOADS)
    put(MediaStore.Downloads.IS_PENDING,1)
   }
   val uri=contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,values)
    ?:throw IOException("Could not create Downloads file")
   try {
    contentResolver.openOutputStream(uri)?.use { output ->
     file.inputStream().use { it.copyTo(output) }
    } ?: throw IOException("Could not write Downloads file")
    contentResolver.update(uri,ContentValues().apply { put(MediaStore.Downloads.IS_PENDING,0) },null,null)
    return uri
   } catch(e:Exception) {
    contentResolver.delete(uri,null,null)
    throw e
   }
  }
  val dir=getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
  dir.mkdirs()
  val destination=File(dir,name.substringAfterLast('/').replace("..","_"))
  file.copyTo(destination,overwrite=true)
  return Uri.fromFile(destination)
 }
}
