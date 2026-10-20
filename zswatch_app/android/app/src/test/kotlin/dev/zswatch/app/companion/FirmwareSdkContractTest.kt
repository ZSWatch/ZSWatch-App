package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.response.img.McuMgrImageStateResponse

class FirmwareSdkContractTest {
    /** Tiny structurally valid MCUboot fixture, never sent to hardware or claimed signed. */
    private fun image(): ByteArray {
        val bytes=ByteArray(76);val buffer=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        buffer.putInt(0,0x96f3b83d.toInt());buffer.putShort(8,32);buffer.putInt(12,4)
        buffer.putShort(36,0x6907);buffer.putShort(38,40)
        buffer.put(40,0x10);buffer.putShort(42,32)
        for(i in 44 until 76)bytes[i]=0xab.toByte()
        return bytes
    }
    @Test fun existingSettingsPreserveUserDataAndUploadConfiguration() {
        val settings=FirmwareSdkContract.settings()
        assertFalse(settings.eraseAppSettings);assertEquals(3,settings.windowCapacity);assertEquals(4,settings.memoryAlignment)
    }
    @Test fun nordicParserPreservesSingleExternalImageIndexAndCopiesInput() {
        val bytes=image();val parsed=FirmwareSdkContract.parse(listOf(2 to bytes)).single()
        assertEquals(2,parsed.imageIndex);assertEquals(32,parsed.image.hash.size)
        bytes[44]=0
        assertEquals(0xab.toByte(),parsed.image.data[44]);assertEquals(0xab.toByte(),parsed.image.hash[0])
        val multiple=FirmwareSdkContract.parse(listOf(2 to image(),0 to image()))
        assertEquals(listOf(2,0),multiple.map{it.imageIndex})
    }
    @Test fun invalidStructureAndConflictingIndicesAreRejectedByPreflight() {
        assertThrows(McuMgrException::class.java){FirmwareSdkContract.parse(listOf(0 to ByteArray(32)))}
        assertThrows(IllegalArgumentException::class.java){FirmwareSdkContract.parse(listOf(0 to image(),0 to image()))}
        assertThrows(IllegalArgumentException::class.java){FirmwareSdkContract.parse(listOf(3 to image()))}
    }
    private fun installed(index:Int,hash:Byte,active:Boolean)=McuMgrImageStateResponse.ImageSlot().also{
        it.image=index;it.hash=ByteArray(32){hash};it.active=active
    }
    @Test fun actualImageStateResponseMustMatchEverySelectedActiveImage() {
        val targets=listOf(FirmwareTarget(0,76,"ab".repeat(32)),FirmwareTarget(2,76,"cd".repeat(32)))
        val response=McuMgrImageStateResponse()
        response.images=arrayOf(installed(0,0xab.toByte(),true),installed(2,0xcd.toByte(),true))
        FirmwareSdkContract.checkActive(targets,response)
        response.images[1].active=false
        assertThrows(IllegalStateException::class.java){FirmwareSdkContract.checkActive(targets,response)}
        response.images[1].active=true;response.images[1].image=1
        val missing=assertThrows(FirmwareVerificationUnavailable::class.java){FirmwareSdkContract.checkActive(targets,response)}
        assertEquals(listOf(2),missing.missingIndices)
        response.images[1].image=2;response.images[1].hash[0]=0
        assertThrows(IllegalStateException::class.java){FirmwareSdkContract.checkActive(targets,response)}
        response.images=null
        assertThrows(FirmwareVerificationUnavailable::class.java){FirmwareSdkContract.checkActive(targets,response)}
    }
    @Test fun unreportedNetworkCoreIsLeftToMcuboot() {
        val targets=listOf(FirmwareTarget(0,76,"ab".repeat(32)),FirmwareTarget(1,76,"ef".repeat(32)),FirmwareTarget(2,76,"cd".repeat(32)))
        val response=McuMgrImageStateResponse()
        // The nRF5340 app core cannot list the network core's primary slot.
        response.images=arrayOf(installed(0,0xab.toByte(),true),installed(2,0xcd.toByte(),true))
        FirmwareSdkContract.checkActive(targets,response)
        // When the watch does report image 1, it must match.
        response.images=arrayOf(installed(0,0xab.toByte(),true),installed(1,0x00,true),installed(2,0xcd.toByte(),true))
        assertThrows(IllegalStateException::class.java){FirmwareSdkContract.checkActive(targets,response)}
    }
}
