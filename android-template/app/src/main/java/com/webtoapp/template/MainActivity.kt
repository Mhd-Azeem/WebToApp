package com.webtoapp.template

import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.View
import android.widget.*
import android.util.Base64
import com.canhub.cropper.CropImageContract
import com.canhub.cropper.CropImageContractOptions
import com.canhub.cropper.CropImageOptions
import com.canhub.cropper.CropImageView
import java.io.ByteArrayOutputStream
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.concurrent.thread

class MainActivity : AppCompatActivity() {
    private val owner = "Mhd-Azeem"
    private val repo = "WebToApp"
    private val workflow = "build-custom-apk.yml"
    private val prefs by lazy { getSharedPreferences("webtoapp", MODE_PRIVATE) }
    private val handler = Handler(Looper.getMainLooper())
    private var iconBase64 = ""
    private val cropIcon = registerForActivityResult(CropImageContract()) { result ->
        if (result.isSuccessful && result.uriContent != null) {
            val uri = result.uriContent!!
            thread {
                try {
                    val bitmap = contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
                    val scaled = Bitmap.createScaledBitmap(bitmap, 192, 192, true)
                    val out = ByteArrayOutputStream()
                    scaled.compress(Bitmap.CompressFormat.JPEG, 82, out)
                    iconBase64 = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
                    ui { findViewById<ImageView>(R.id.iconPreview).setImageBitmap(scaled); Toast.makeText(this, "Icon cropped and ready", Toast.LENGTH_SHORT).show() }
                } catch (e: Exception) { ui { Toast.makeText(this, "Could not process icon", Toast.LENGTH_SHORT).show() } }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val websiteUrl = findViewById<EditText>(R.id.websiteUrl)
        val appName = findViewById<EditText>(R.id.appName)
        val packageName = findViewById<EditText>(R.id.packageName)
        val orientationGroup = findViewById<RadioGroup>(R.id.orientationGroup)
        val build = findViewById<Button>(R.id.buildButton)
        val status = findViewById<TextView>(R.id.statusText)
        val progress = findViewById<ProgressBar>(R.id.progressBar)

        findViewById<Button>(R.id.githubButton).setOnClickListener { askForToken() }
        findViewById<Button>(R.id.iconButton).setOnClickListener {
            cropIcon.launch(CropImageContractOptions(null, CropImageOptions(
                fixAspectRatio = true,
                aspectRatioX = 1,
                aspectRatioY = 1,
                imageSourceIncludeGallery = true,
                imageSourceIncludeCamera = true,
                cropMenuCropButtonTitle = "ADD PHOTO",
                activityMenuIconColor = android.graphics.Color.BLACK,
                toolbarColor = android.graphics.Color.WHITE,
                toolbarBackButtonColor = android.graphics.Color.BLACK,
                toolbarTintColor = android.graphics.Color.BLACK,
                toolbarTitleColor = android.graphics.Color.BLACK
            )))
        }
        findViewById<Button>(R.id.previewButton).setOnClickListener {
            val u = normalizeUrl(websiteUrl.text.toString())
            if (!isValidUrl(u)) websiteUrl.error = "Enter a valid website URL"
            else startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u)))
        }

        build.setOnClickListener {
            val u = normalizeUrl(websiteUrl.text.toString())
            val n = appName.text.toString().trim()
            val p = packageName.text.toString().trim()
            val token = prefs.getString("github_token", null)

            when {
                !isValidUrl(u) -> websiteUrl.error = "Enter a valid http/https URL"
                n.isBlank() -> appName.error = "Enter an app name"
                !p.matches(Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")) ->
                    packageName.error = "Example: com.company.app"
                token.isNullOrBlank() -> askForToken()
                else -> {
                    val orientation = when (orientationGroup.checkedRadioButtonId) {
                        R.id.orientationPortrait -> "portrait"
                        R.id.orientationLandscape -> "landscape"
                        else -> "auto"
                    }
                    build.isEnabled = false
                    progress.visibility = View.VISIBLE
                    status.text = "Starting APK build…"
                    dispatchBuild(token, u, n, p, orientation, build, progress, status)
                }
            }
        }
    }

    private fun askForToken() {
        val input = EditText(this).apply {
            hint = "GitHub token"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            setPadding(48, 20, 48, 20)
        }
        AlertDialog.Builder(this)
            .setTitle("Connect GitHub")
            .setMessage("Enter a fine-grained GitHub token with Actions write access to Mhd-Azeem/WebToApp. It is stored only on this device.")
            .setView(input)
            .setPositiveButton("Save") { _, _ ->
                val value = input.text.toString().trim()
                if (value.isNotEmpty()) {
                    prefs.edit().putString("github_token", value).apply()
                    Toast.makeText(this, "GitHub connected", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun dispatchBuild(token:String, site:String, name:String, pkg:String, orientation:String,
                              button:Button, progress:ProgressBar, status:TextView) {
        thread {
            try {
                val body = JSONObject().apply {
                    put("ref", "main")
                    put("inputs", JSONObject().apply {
                        put("website_url", site)
                        put("app_name", name)
                        put("package_name", pkg)
                        put("orientation", orientation)
                        put("icon_base64", iconBase64)
                    })
                }.toString()
                val code = request(
                    "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow/dispatches",
                    "POST", token, body
                ).first
                if (code !in 200..299) throw Exception("GitHub returned HTTP $code")
                ui { status.text = "Build queued on GitHub Actions…" }
                Thread.sleep(5000)
                pollBuild(token, name, button, progress, status)
            } catch (e:Exception) {
                ui {
                    status.text = "Build could not start: ${e.message}"
                    progress.visibility = View.GONE
                    button.isEnabled = true
                }
            }
        }
    }

    private fun pollBuild(token:String, appName:String, button:Button, progress:ProgressBar, status:TextView) {
        repeat(90) {
            val (_, text) = request(
                "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow/runs?event=workflow_dispatch&per_page=1",
                "GET", token, null
            )
            val runs = JSONObject(text).optJSONArray("workflow_runs")
            if (runs != null && runs.length() > 0) {
                val run = runs.getJSONObject(0)
                val state = run.optString("status")
                val conclusion = run.optString("conclusion")
                ui { status.text = if (state == "completed") "Build finished: $conclusion" else "Building APK… $state" }
                if (state == "completed") {
                    ui {
                        progress.visibility = View.GONE
                        button.isEnabled = true
                        if (conclusion == "success") {
                            status.text = "APK ready. Opening download…"
                            val encoded = URLEncoder.encode(appName, "UTF-8").replace("+", "%20")
                            startActivity(Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/$owner/$repo/releases/download/generated-latest/$encoded.apk")))
                        } else status.text = "APK build failed. Check GitHub Actions."
                    }
                    return
                }
            }
            Thread.sleep(5000)
        }
        ui {
            progress.visibility = View.GONE
            button.isEnabled = true
            status.text = "Build is taking longer than expected. Check GitHub Actions."
        }
    }

    private fun request(endpoint:String, method:String, token:String, body:String?): Pair<Int,String> {
        val c = URL(endpoint).openConnection() as HttpURLConnection
        c.requestMethod = method
        c.setRequestProperty("Authorization", "Bearer $token")
        c.setRequestProperty("Accept", "application/vnd.github+json")
        c.setRequestProperty("X-GitHub-Api-Version", "2022-11-28")
        c.connectTimeout = 15000
        c.readTimeout = 15000
        if (body != null) {
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(body.toByteArray()) }
        }
        val code = c.responseCode
        val stream = if (code in 200..299) c.inputStream else c.errorStream
        return code to (stream?.bufferedReader()?.use { it.readText() } ?: "")
    }

    private fun ui(block:()->Unit) = handler.post(block)
    private fun normalizeUrl(v:String):String {
        val s=v.trim()
        return if (s.startsWith("http://",true)||s.startsWith("https://",true)) s else "https://$s"
    }
    private fun isValidUrl(v:String):Boolean {
        val u=runCatching { Uri.parse(v) }.getOrNull() ?: return false
        return (u.scheme=="http"||u.scheme=="https") && !u.host.isNullOrBlank()
    }
}
