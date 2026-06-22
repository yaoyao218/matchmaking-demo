// 50位元遮罩還原成 5x10 座標
export function decompressMask(mask: bigint): { day: number; period: number }[] {
  const coords: { day: number; period: number }[] = [];
  for (let i = 0; i < 50; i++) {
    if ((mask & (1n << BigInt(i))) !== 0n) {
      coords.push({ day: Math.floor(i / 10) + 1, period: (i % 10) + 1 });
    }
  }
  return coords;
}

// 動態疊加運算
export function calculateOverlay(groupMaskStr: string, studentMaskStr: string) {
  const groupMask = BigInt(groupMaskStr);
  const studentMask = BigInt(studentMaskStr);
  const totalSlotsMask = (1n << 50n) - 1n;

  const conflictMask = groupMask & studentMask;
  const goldenMask = ~(groupMask | studentMask) & totalSlotsMask;

  return {
    hasConflict: conflictMask > 0n,
    conflictSlots: decompressMask(conflictMask),
    goldenSlots: decompressMask(goldenMask)
  };
}
