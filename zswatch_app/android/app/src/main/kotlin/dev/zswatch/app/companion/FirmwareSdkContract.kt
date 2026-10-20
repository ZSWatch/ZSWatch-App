package dev.zswatch.app.companion

import io.runtime.mcumgr.dfu.mcuboot.FirmwareUpgradeManager
import io.runtime.mcumgr.dfu.mcuboot.model.TargetImage
import io.runtime.mcumgr.response.img.McuMgrImageStateResponse

/** Nordic owns image parsing and the SMP transport. */
internal object FirmwareSdkContract {
    fun parse(images: List<Pair<Int, ByteArray>>): List<TargetImage> {
        require(images.size in 1..3 && images.map { it.first }.distinct().size == images.size)
        require(images.all { it.first in 0..2 && it.second.size in 1..PrototypeFirmware.MAX_IMAGE_BYTES })
        return images.map { TargetImage(it.first, it.second.copyOf()) }
    }
    fun settings(): FirmwareUpgradeManager.Settings = FirmwareUpgradeManager.Settings.Builder()
        // The watch has four SMP buffers. Leave one free while keeping three
        // requests in flight, as the existing file uploader already does.
        .setEraseAppSettings(false).setWindowCapacity(3).setMemoryAlignment(4).build()

    fun checkActive(targets: List<FirmwareTarget>, response: McuMgrImageStateResponse) {
        check(response.isSuccess) { "Image state rejected" }
        val reported = response.images?.toList() ?: emptyList()
        // The nRF5340 app core cannot read the network core's primary slot (ram_flash),
        // so image 1 is usually not listed; MCUboot verifies it while copying it over.
        val checked = targets.filter { target -> target.index != 1 || reported.any { it.image == 1 } }
        val missing = checked.map { it.index }.filter { index -> reported.none { it.image == index } }
        if (missing.isNotEmpty()) throw FirmwareVerificationUnavailable(missing)
        val active = reported.filter { it.active }
        check(checked.all { target -> active.any { image -> image.image == target.index &&
            image.hash?.joinToString("") { byte -> "%02x".format(byte) } == target.hash } }) { "Active firmware does not match selection" }
    }
}
