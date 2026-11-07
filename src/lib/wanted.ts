import type { IconName } from '../components/Icon.astro';

// Screens nobody has decked yet. When one gets a verified entry in
// src/content/devices, remove it from here.
export const WANTED: { name: string; why: string; icon: IconName }[] = [
  { name: 'Kindle 4 or Kindle Keyboard', why: 'No touchscreen at all, just a 5-way pad. The perfect test for the non-touch idea.', icon: 'dpad' },
  { name: 'Kobo with KOReader', why: 'Same e-ink, friendlier to hack. Probably half an hour with the Kindle recipe as a base.', icon: 'ereader' },
  { name: 'Old iPad (iOS 9 to 12)', why: 'Millions of them in drawers. Old Safari, big screen, perfect for 20 buttons.', icon: 'tablet' },
  { name: 'Android phone or tablet', why: 'Any version with a browser. Kiosk mode makes it feel like real hardware.', icon: 'phone' },
  { name: 'Android TV or Google TV', why: 'Drive it from the sofa with the remote. No touch involved.', icon: 'remote' },
  { name: 'Raspberry Pi with a screen', why: 'A touch display or a few physical buttons and a tiny screen.', icon: 'board' },
  { name: 'Steam Deck', why: 'A Steam Deck as a Stream Deck. Somebody has to do it.', icon: 'gamepad' },
  { name: 'Your weird screen', why: 'A smart fridge, an old GPS, a car display. Surprise us.', icon: 'sparkle' },
];
