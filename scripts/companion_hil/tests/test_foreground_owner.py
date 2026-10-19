import unittest

from native_runtime_probe import COMPONENT, connected_device_foreground


class ForegroundOwnerTest(unittest.TestCase):
    @staticmethod
    def record(component=COMPONENT, foreground=True, types='0x00000010'):
        return f'  * ServiceRecord{{owned u0 com.zswatch.app/{component}}}\n' \
            f'    isForeground={str(foreground).lower()} foregroundId=1003 types={types} foregroundNoti=Notification()\n'

    def test_connected_device_with_location_is_still_connected_device_foreground(self):
        for types in ('0x00000010', '0x00000018', '0x00200010'):
            self.assertTrue(connected_device_foreground(self.record(types=types)))

    def test_missing_type_or_nonforeground_owner_is_not_healthy(self):
        for types in ('0x00000000', '0x00000008'):
            self.assertFalse(connected_device_foreground(self.record(types=types)))
        self.assertFalse(connected_device_foreground(self.record(foreground=False)))
        self.assertFalse(connected_device_foreground(self.record().replace(' types=0x00000010', '')))

    def test_other_foreground_service_and_connections_cannot_mask_the_owner(self):
        other = self.record(component='dev.zswatch.app.LlmComputeService') + f'    connection={COMPONENT}\n'
        self.assertFalse(connected_device_foreground(other))
        self.assertFalse(connected_device_foreground(other + self.record(foreground=False)))
        self.assertTrue(connected_device_foreground(other + self.record(types='0x00000018')))


if __name__ == '__main__':
    unittest.main()
