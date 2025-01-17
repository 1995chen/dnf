
/**
 *  * @author XanderYe
 *   * @description: DNF数据库TEA加密算法
 *    * @date 2021/12/29 20:43
 *     */
public class TeaEncrypt {
    private static final String KEY = "troqkddmtroqkcdm";

    private static final String POSTFIX = "e8b10c1f8bc3595be8b10c1f8bc3595b";

    private static final String[] HEX_ARRAY = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"};

    public static String getKey(String sixkey) {
        String res1 = encrypt(sixkey);
        return res1 + POSTFIX;
    }

    private static int strToInt(String t) {
        char[] chs = t.toCharArray();
        int a = chs[0] << 24;
        int b = chs[1] << 16;
        int c = chs[2] << 8;
        int d = chs[3];
        return a + b + c + d;
    }

    private static String intToStr(int v) {
        int a = (0xFF000000 & v) >> 24;
        int b = (0xFF0000 & v) >> 16;
        int c = (0xFF00 & v) >> 8;
        int d = 0xFF & v;
        return byteToHex(a) + byteToHex(b) + byteToHex(c) + byteToHex(d);
    }

    private static String byteToHex(int n) {
        if (n < 0) {
            n = n + 256;
        }
        int d1 = n / 16;
        int d2 = n % 16;
        return HEX_ARRAY[d1] + HEX_ARRAY[d2];
    }

    private static int unpack(String tmp, int start) {
        char[] arr = tmp.substring(start).toCharArray();
        int d = arr[0];
        int c = arr[1];
        int b = arr[2];
        int a = arr[3];
        a = a << 24;
        b = b << 16;
        c = c << 8;
        return a + b + c + d;
    }

    private static String encrypt(String v) {
        int v0 = strToInt(v);
        int v1 = strToInt(v.substring(4));
        int sum = 0;
        for (int i = 0; i < 32; i++) {
            int tv1 = (v1 << 4) ^ (v1 >> 5 & 0x07FFFFFF);
            int tv2 = unpack(KEY, (sum & 3) * 4);
            v0 = v0 + ((tv1 + v1) ^ (tv2 + sum));
            sum = sum + 0x9E3779B9;
            tv1 = (((v0 << 4)) ^ ((v0 >> 5 & 0x07FFFFFF)));
            tv2 = unpack(KEY, ((sum >> 11) & 3) * 4);
            v1 = (v1 + ((tv1 + v0) ^ (tv2 + sum)));
        }
        return intToStr(v0) + intToStr(v1);
    }

    public static void main(String[] args) {
        String password = "uu5!^%jg";
        String key = getKey(password);
        System.out.println(key);
    }
}
