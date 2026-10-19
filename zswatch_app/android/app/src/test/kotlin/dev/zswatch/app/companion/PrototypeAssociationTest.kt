package dev.zswatch.app.companion

import android.bluetooth.BluetoothDevice
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*

class PrototypeAssociationTest {
    private fun device(address: String, name: String?, bonded: Boolean = true): BluetoothDevice =
        mock(BluetoothDevice::class.java).also {
            `when`(it.address).thenReturn(address)
            `when`(it.name).thenReturn(name)
            `when`(it.bondState).thenReturn(if (bonded) BluetoothDevice.BOND_BONDED else BluetoothDevice.BOND_NONE)
        }

    @Test fun systemConnectionsIdentifyOnlyOneBondedWatchWithoutSelectingAnArbitraryPeer() {
        val watch = device("AA:BB:CC:DD:EE:FF", "ZSWatch")
        val duplicate = device("aa:bb:cc:dd:ee:ff", "zswatch")
        val other = device("11:22:33:44:55:66", "Headphones")
        assertEquals("AA:BB:CC:DD:EE:FF", PrototypeAssociation.connectedWatch(listOf(watch, duplicate, other)))
        assertNull(PrototypeAssociation.connectedWatch(listOf(other)))
        assertNull(PrototypeAssociation.connectedWatch(listOf(device("11:22:33:44:55:66", null))))
        assertNull(PrototypeAssociation.connectedWatch(listOf(device("11:22:33:44:55:66", "ZSWatch", false))))
        assertNull(PrototypeAssociation.connectedWatch(listOf(watch, device("11:22:33:44:55:66", "ZSWatch"))))
    }
}
