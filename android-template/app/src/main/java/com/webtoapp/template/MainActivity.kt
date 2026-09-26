package com.webtoapp.template

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val websiteUrl = findViewById<EditText>(R.id.websiteUrl)
        val appName = findViewById<EditText>(R.id.appName)
        val packageName = findViewById<EditText>(R.id.packageName)
        val orientationGroup = findViewById<RadioGroup>(R.id.orientationGroup)
        val resultText = findViewById<TextView>(R.id.resultText)

        val features = linkedMapOf(
            "fileUpload" to findViewById<CheckBox>(R.id.featureUpload),
            "downloads" to findViewById<CheckBox>(R.id.featureDownloads),
            "camera" to findViewById<CheckBox>(R.id.featureCamera),
            "microphone" to findViewById<CheckBox>(R.id.featureMicrophone),
            "location" to findViewById<CheckBox>(R.id.featureLocation),
            "pullToRefresh" to findViewById<CheckBox>(R.id.featureRefresh),
            "fullscreenVideo" to findViewById<CheckBox>(R.id.featureFullscreen),
            "share" to findViewById<CheckBox>(R.id.featureShare),
            "offlinePage" to findViewById<CheckBox>(R.id.featureOffline)
        )

        findViewById<Button>(R.id.generateButton).setOnClickListener {
            val url = normalizeUrl(websiteUrl.text.toString())
            val name = appName.text.toString().trim()
            val pkg = packageName.text.toString().trim()

            if (!isValidUrl(url)) {
                websiteUrl.error = "Enter a valid http or https website URL"
                return@setOnClickListener
            }
            if (name.isBlank()) {
                appName.error = "Enter an app name"
                return@setOnClickListener
            }
            if (!pkg.matches(Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$"))) {
                packageName.error = "Example: com.company.app"
                return@setOnClickListener
            }

            val orientation = when (orientationGroup.checkedRadioButtonId) {
                R.id.orientationPortrait -> "portrait"
                R.id.orientationLandscape -> "landscape"
                else -> "auto"
            }

            val featureJson = JSONObject()
            features.forEach { (key, box) -> featureJson.put(key, box.isChecked) }

            val config = JSONObject().apply {
                put("appName", name)
                put("packageName", pkg)
                put("websiteUrl", url)
                put("orientation", orientation)
                put("features", featureJson)
            }

            resultText.text = config.toString(2)
            Toast.makeText(this, "Configuration generated", Toast.LENGTH_SHORT).show()
        }

        findViewById<Button>(R.id.previewButton).setOnClickListener {
            val url = normalizeUrl(websiteUrl.text.toString())
            if (!isValidUrl(url)) {
                websiteUrl.error = "Enter a valid website URL"
            } else {
                runCatching {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                }.onFailure {
                    Toast.makeText(this, "Unable to open website", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun normalizeUrl(value: String): String {
        val trimmed = value.trim()
        if (trimmed.isBlank()) return trimmed
        return if (trimmed.startsWith("http://", true) || trimmed.startsWith("https://", true)) trimmed else "https://$trimmed"
    }

    private fun isValidUrl(value: String): Boolean {
        val uri = runCatching { Uri.parse(value) }.getOrNull() ?: return false
        return (uri.scheme == "http" || uri.scheme == "https") && !uri.host.isNullOrBlank()
    }
}
