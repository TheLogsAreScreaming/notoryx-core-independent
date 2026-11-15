package com.bastionmesh.notoryx_core

import android.app.Activity
import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The phone's compass heading, relative to magnetic north, from the
 * rotation-vector sensor, about 20 times a second while Flutter listens.
 * Sends a map of heading (degrees, 0 to 360) and accuracy (0 to 3).
 */
class HeadingStream(private val activity: Activity) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotation: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private var sink: EventChannel.EventSink? = null
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM
    private val matrix = FloatArray(9)
    private val remapped = FloatArray(9)
    private val angles = FloatArray(3)

    val available: Boolean get() = rotation != null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = rotation
        if (sensor == null) {
            events.error("no_compass", "This phone has no rotation sensor", null)
            return
        }
        sink = events
        sensors.registerListener(this, sensor, 50_000)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, value: Int) {
        accuracy = value
    }

    override fun onSensorChanged(event: SensorEvent) {
        val events = sink ?: return
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        val (x, y) = when (displayRotation()) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(matrix, x, y, remapped)
        SensorManager.getOrientation(remapped, angles)
        val degrees = (Math.toDegrees(angles[0].toDouble()) + 360) % 360
        events.success(mapOf("heading" to degrees, "accuracy" to accuracy))
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            activity.windowManager.defaultDisplay.rotation
        }

    /** Handles "declination" (degrees east of true north) and "available". */
    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(available)
            "declination" -> {
                val lat = call.argument<Double>("lat")
                val lon = call.argument<Double>("lon")
                if (lat == null || lon == null) {
                    result.error("bad_args", "lat and lon are needed", null)
                    return
                }
                val alt = call.argument<Double>("alt") ?: 0.0
                val field = GeomagneticField(
                    lat.toFloat(),
                    lon.toFloat(),
                    alt.toFloat(),
                    System.currentTimeMillis(),
                )
                result.success(field.declination.toDouble())
            }
            else -> result.notImplemented()
        }
    }
}
