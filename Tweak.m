#import <Foundation/Foundation.h>
#include <sys/time.h>
#include <mach/mach_time.h>
#include <dispatch/dispatch.h>

static double speedMultiplier = 5.0; 
static bool isSafeToSpeedUp = false; 

// ระบบฮุกดั้งเดิมของ Apple ไม่ง้อ Substrate (โคตรเสถียรสำหรับสาย Sideload)
#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// --- Hook 1: gettimeofday ---
static int my_gettimeofday(struct timeval *tv, struct timezone *tz) {
    int ret = gettimeofday(tv, tz); // วิ่งหาฟังก์ชั่นแท้อัตโนมัติ
    if (ret == 0 && tv != NULL) {
        static struct timeval base_tv = {0};
        if (base_tv.tv_sec == 0) {
            base_tv = *tv;
        } else if (isSafeToSpeedUp) {
            long long diff_usec = (tv->tv_sec - base_tv.tv_sec) * 1000000LL + (tv->tv_usec - base_tv.tv_usec);
            long long speed_diff = (long long)((double)diff_usec * speedMultiplier);
            tv->tv_sec = base_tv.tv_sec + (speed_diff / 1000000LL);
            tv->tv_usec = base_tv.tv_usec + (speed_diff % 1000000LL);
        } else {
            base_tv = *tv;
        }
    }
    return ret;
}
DYLD_INTERPOSE(my_gettimeofday, gettimeofday);

// --- Hook 2: mach_absolute_time (หัวใจหลักที่ทำให้เกมไม่เด้ง) ---
static uint64_t my_mach_absolute_time(void) {
    uint64_t ret = mach_absolute_time();
    static uint64_t base_time = 0;
    
    if (base_time == 0) {
        base_time = ret;
    } else if (isSafeToSpeedUp) {
        uint64_t diff = ret - base_time;
        return base_time + (uint64_t)((double)diff * speedMultiplier);
    } else {
        base_time = ret;
    }
    return ret;
}
DYLD_INTERPOSE(my_mach_absolute_time, mach_absolute_time);

// --- ดีเลย์กันเซิร์ฟเวอร์จับได้ 15 วินาที ---
__attribute__((constructor)) static void init_native_speedhack() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        isSafeToSpeedUp = true;
    });
}
