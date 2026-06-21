const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;
pub extern fn Pa_GetVersion() c_int;
pub extern fn Pa_GetVersionText() [*c]const u8;
pub const struct_PaVersionInfo = extern struct {
    versionMajor: c_int = 0,
    versionMinor: c_int = 0,
    versionSubMinor: c_int = 0,
    versionControlRevision: [*c]const u8 = null,
    versionText: [*c]const u8 = null,
};
pub const PaVersionInfo = struct_PaVersionInfo;
pub extern fn Pa_GetVersionInfo() [*c]const PaVersionInfo;
pub const PaError = c_int;
pub const paNoError: c_int = 0;
pub const paNotInitialized: c_int = -10000;
pub const paUnanticipatedHostError: c_int = -9999;
pub const paInvalidChannelCount: c_int = -9998;
pub const paInvalidSampleRate: c_int = -9997;
pub const paInvalidDevice: c_int = -9996;
pub const paInvalidFlag: c_int = -9995;
pub const paSampleFormatNotSupported: c_int = -9994;
pub const paBadIODeviceCombination: c_int = -9993;
pub const paInsufficientMemory: c_int = -9992;
pub const paBufferTooBig: c_int = -9991;
pub const paBufferTooSmall: c_int = -9990;
pub const paNullCallback: c_int = -9989;
pub const paBadStreamPtr: c_int = -9988;
pub const paTimedOut: c_int = -9987;
pub const paInternalError: c_int = -9986;
pub const paDeviceUnavailable: c_int = -9985;
pub const paIncompatibleHostApiSpecificStreamInfo: c_int = -9984;
pub const paStreamIsStopped: c_int = -9983;
pub const paStreamIsNotStopped: c_int = -9982;
pub const paInputOverflowed: c_int = -9981;
pub const paOutputUnderflowed: c_int = -9980;
pub const paHostApiNotFound: c_int = -9979;
pub const paInvalidHostApi: c_int = -9978;
pub const paCanNotReadFromACallbackStream: c_int = -9977;
pub const paCanNotWriteToACallbackStream: c_int = -9976;
pub const paCanNotReadFromAnOutputOnlyStream: c_int = -9975;
pub const paCanNotWriteToAnInputOnlyStream: c_int = -9974;
pub const paIncompatibleStreamHostApi: c_int = -9973;
pub const paBadBufferPtr: c_int = -9972;
pub const enum_PaErrorCode = c_int;
pub const PaErrorCode = enum_PaErrorCode;
pub extern fn Pa_GetErrorText(errorCode: PaError) [*c]const u8;
pub extern fn Pa_Initialize() PaError;
pub extern fn Pa_Terminate() PaError;
pub const PaDeviceIndex = c_int;
pub const PaHostApiIndex = c_int;
pub extern fn Pa_GetHostApiCount() PaHostApiIndex;
pub extern fn Pa_GetDefaultHostApi() PaHostApiIndex;
pub const paInDevelopment: c_int = 0;
pub const paDirectSound: c_int = 1;
pub const paMME: c_int = 2;
pub const paASIO: c_int = 3;
pub const paSoundManager: c_int = 4;
pub const paCoreAudio: c_int = 5;
pub const paOSS: c_int = 7;
pub const paALSA: c_int = 8;
pub const paAL: c_int = 9;
pub const paBeOS: c_int = 10;
pub const paWDMKS: c_int = 11;
pub const paJACK: c_int = 12;
pub const paWASAPI: c_int = 13;
pub const paAudioScienceHPI: c_int = 14;
pub const enum_PaHostApiTypeId = c_uint;
pub const PaHostApiTypeId = enum_PaHostApiTypeId;
pub const struct_PaHostApiInfo = extern struct {
    structVersion: c_int = 0,
    type: PaHostApiTypeId = @import("std").mem.zeroes(PaHostApiTypeId),
    name: [*c]const u8 = null,
    deviceCount: c_int = 0,
    defaultInputDevice: PaDeviceIndex = 0,
    defaultOutputDevice: PaDeviceIndex = 0,
};
pub const PaHostApiInfo = struct_PaHostApiInfo;
pub extern fn Pa_GetHostApiInfo(hostApi: PaHostApiIndex) [*c]const PaHostApiInfo;
pub extern fn Pa_HostApiTypeIdToHostApiIndex(@"type": PaHostApiTypeId) PaHostApiIndex;
pub extern fn Pa_HostApiDeviceIndexToDeviceIndex(hostApi: PaHostApiIndex, hostApiDeviceIndex: c_int) PaDeviceIndex;
pub const struct_PaHostErrorInfo = extern struct {
    hostApiType: PaHostApiTypeId = @import("std").mem.zeroes(PaHostApiTypeId),
    errorCode: c_long = 0,
    errorText: [*c]const u8 = null,
};
pub const PaHostErrorInfo = struct_PaHostErrorInfo;
pub extern fn Pa_GetLastHostErrorInfo() [*c]const PaHostErrorInfo;
pub extern fn Pa_GetDeviceCount() PaDeviceIndex;
pub extern fn Pa_GetDefaultInputDevice() PaDeviceIndex;
pub extern fn Pa_GetDefaultOutputDevice() PaDeviceIndex;
pub const PaTime = f64;
pub const PaSampleFormat = c_ulong;
pub const struct_PaDeviceInfo = extern struct {
    structVersion: c_int = 0,
    name: [*c]const u8 = null,
    hostApi: PaHostApiIndex = 0,
    maxInputChannels: c_int = 0,
    maxOutputChannels: c_int = 0,
    defaultLowInputLatency: PaTime = 0,
    defaultLowOutputLatency: PaTime = 0,
    defaultHighInputLatency: PaTime = 0,
    defaultHighOutputLatency: PaTime = 0,
    defaultSampleRate: f64 = 0,
};
pub const PaDeviceInfo = struct_PaDeviceInfo;
pub extern fn Pa_GetDeviceInfo(device: PaDeviceIndex) [*c]const PaDeviceInfo;
pub const struct_PaStreamParameters = extern struct {
    device: PaDeviceIndex = 0,
    channelCount: c_int = 0,
    sampleFormat: PaSampleFormat = 0,
    suggestedLatency: PaTime = 0,
    hostApiSpecificStreamInfo: ?*anyopaque = null,
    pub const Pa_IsFormatSupported = __root.Pa_IsFormatSupported;
    pub const IsFormatSupported = __root.Pa_IsFormatSupported;
};
pub const PaStreamParameters = struct_PaStreamParameters;
pub extern fn Pa_IsFormatSupported(inputParameters: [*c]const PaStreamParameters, outputParameters: [*c]const PaStreamParameters, sampleRate: f64) PaError;
pub const PaStream = anyopaque;
pub const PaStreamFlags = c_ulong;
pub const struct_PaStreamCallbackTimeInfo = extern struct {
    inputBufferAdcTime: PaTime = 0,
    currentTime: PaTime = 0,
    outputBufferDacTime: PaTime = 0,
};
pub const PaStreamCallbackTimeInfo = struct_PaStreamCallbackTimeInfo;
pub const PaStreamCallbackFlags = c_ulong;
pub const paContinue: c_int = 0;
pub const paComplete: c_int = 1;
pub const paAbort: c_int = 2;
pub const enum_PaStreamCallbackResult = c_uint;
pub const PaStreamCallbackResult = enum_PaStreamCallbackResult;
pub const PaStreamCallback = fn (input: ?*const anyopaque, output: ?*anyopaque, frameCount: c_ulong, timeInfo: [*c]const PaStreamCallbackTimeInfo, statusFlags: PaStreamCallbackFlags, userData: ?*anyopaque) callconv(.c) c_int;
pub extern fn Pa_OpenStream(stream: [*c]?*PaStream, inputParameters: [*c]const PaStreamParameters, outputParameters: [*c]const PaStreamParameters, sampleRate: f64, framesPerBuffer: c_ulong, streamFlags: PaStreamFlags, streamCallback: ?*const PaStreamCallback, userData: ?*anyopaque) PaError;
pub extern fn Pa_OpenDefaultStream(stream: [*c]?*PaStream, numInputChannels: c_int, numOutputChannels: c_int, sampleFormat: PaSampleFormat, sampleRate: f64, framesPerBuffer: c_ulong, streamCallback: ?*const PaStreamCallback, userData: ?*anyopaque) PaError;
pub extern fn Pa_CloseStream(stream: ?*PaStream) PaError;
pub const PaStreamFinishedCallback = fn (userData: ?*anyopaque) callconv(.c) void;
pub extern fn Pa_SetStreamFinishedCallback(stream: ?*PaStream, streamFinishedCallback: ?*const PaStreamFinishedCallback) PaError;
pub extern fn Pa_StartStream(stream: ?*PaStream) PaError;
pub extern fn Pa_StopStream(stream: ?*PaStream) PaError;
pub extern fn Pa_AbortStream(stream: ?*PaStream) PaError;
pub extern fn Pa_IsStreamStopped(stream: ?*PaStream) PaError;
pub extern fn Pa_IsStreamActive(stream: ?*PaStream) PaError;
pub const struct_PaStreamInfo = extern struct {
    structVersion: c_int = 0,
    inputLatency: PaTime = 0,
    outputLatency: PaTime = 0,
    sampleRate: f64 = 0,
};
pub const PaStreamInfo = struct_PaStreamInfo;
pub extern fn Pa_GetStreamInfo(stream: ?*PaStream) [*c]const PaStreamInfo;
pub extern fn Pa_GetStreamTime(stream: ?*PaStream) PaTime;
pub extern fn Pa_GetStreamCpuLoad(stream: ?*PaStream) f64;
pub extern fn Pa_ReadStream(stream: ?*PaStream, buffer: ?*anyopaque, frames: c_ulong) PaError;
pub extern fn Pa_WriteStream(stream: ?*PaStream, buffer: ?*const anyopaque, frames: c_ulong) PaError;
pub extern fn Pa_GetStreamReadAvailable(stream: ?*PaStream) c_long;
pub extern fn Pa_GetStreamWriteAvailable(stream: ?*PaStream) c_long;
pub extern fn Pa_GetSampleSize(format: PaSampleFormat) PaError;
pub extern fn Pa_Sleep(msec: c_long) void;

pub const __VERSION__ = "Aro aro-zig";
pub const __Aro__ = "";
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __GNUC__ = @as(c_int, 7);
pub const __GNUC_MINOR__ = @as(c_int, 1);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 0);
pub const __ARO_EMULATE_NO__ = @as(c_int, 0);
pub const __ARO_EMULATE_CLANG__ = @as(c_int, 1);
pub const __ARO_EMULATE_GCC__ = @as(c_int, 2);
pub const __ARO_EMULATE_MSVC__ = @as(c_int, 3);
pub const __ARO_EMULATE__ = __ARO_EMULATE_GCC__;
pub inline fn __building_module(x: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &x;
    return @as(c_int, 0);
}
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:33:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:34:9
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __VAES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __VPCLMULQDQ__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MWAITX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __SSE4A__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __GFNI__ = @as(c_int, 1);
pub const __EVEX512__ = @as(c_int, 1);
pub const __AVX512CD__ = @as(c_int, 1);
pub const __AVX512VPOPCNTDQ__ = @as(c_int, 1);
pub const __AVX512VNNI__ = @as(c_int, 1);
pub const __AVX512BF16__ = @as(c_int, 1);
pub const __AVX512DQ__ = @as(c_int, 1);
pub const __AVX512BITALG__ = @as(c_int, 1);
pub const __AVX512BW__ = @as(c_int, 1);
pub const __AVX512VL__ = @as(c_int, 1);
pub const __EVEX256__ = @as(c_int, 1);
pub const __AVX512VBMI__ = @as(c_int, 1);
pub const __AVX512VBMI2__ = @as(c_int, 1);
pub const __AVX512IFMA__ = @as(c_int, 1);
pub const __AVX512VP2INTERSECT__ = @as(c_int, 1);
pub const __SHA__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __PKU__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __CLWB__ = @as(c_int, 1);
pub const __WBNOINVD__ = @as(c_int, 1);
pub const __SHSTK__ = @as(c_int, 1);
pub const __CLZERO__ = @as(c_int, 1);
pub const __RDPID__ = @as(c_int, 1);
pub const __RDPRU__ = @as(c_int, 1);
pub const __MOVDIRI__ = @as(c_int, 1);
pub const __MOVDIR64B__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __AVXVNNI__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX512F__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __ELF__ = @as(c_int, 1);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __ATOMIC_BOOL_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WINT_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_SHORT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_INT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LLONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_POINTER_LOCK_FREE = @as(c_int, 1);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SCHAR_WIDTH__ = @as(c_int, 8);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __LONG_LONG_WIDTH__ = @as(c_int, 64);
pub const __WCHAR_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIG_ATOMIC_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __BITINT_MAXWIDTH__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 10);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTPTR_TYPE__ = c_long;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:176:9
pub const __INTMAX_C = __helpers.L_SUFFIX;
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:179:9
pub const __UINTMAX_C = __helpers.UL_SUFFIX;
pub const __PTRDIFF_TYPE__ = c_long;
pub const __SIZE_TYPE__ = c_ulong;
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub inline fn __INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub inline fn __INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub inline fn __INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:205:9
pub const __INT64_C = __helpers.L_SUFFIX;
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub inline fn __UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub inline fn __UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`"); // <builtin>:230:9
pub const __UINT32_C = __helpers.U_SUFFIX;
pub const __UINT32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:239:9
pub const __UINT64_C = __helpers.UL_SUFFIX;
pub const __UINT64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const INT_LEAST8_FMTd__ = "hhd";
pub const INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const UINT_LEAST8_FMTo__ = "hho";
pub const UINT_LEAST8_FMTu__ = "hhu";
pub const UINT_LEAST8_FMTx__ = "hhx";
pub const UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const INT_FAST8_FMTd__ = "hhd";
pub const INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const UINT_FAST8_FMTo__ = "hho";
pub const UINT_FAST8_FMTu__ = "hhu";
pub const UINT_FAST8_FMTx__ = "hhx";
pub const UINT_FAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const INT_LEAST16_FMTd__ = "hd";
pub const INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST16_FMTo__ = "ho";
pub const UINT_LEAST16_FMTu__ = "hu";
pub const UINT_LEAST16_FMTx__ = "hx";
pub const UINT_LEAST16_FMTX__ = "hX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const INT_FAST16_FMTd__ = "hd";
pub const INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_FAST16_FMTo__ = "ho";
pub const UINT_FAST16_FMTu__ = "hu";
pub const UINT_FAST16_FMTx__ = "hx";
pub const UINT_FAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const INT_LEAST32_FMTd__ = "d";
pub const INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST32_FMTo__ = "o";
pub const UINT_LEAST32_FMTu__ = "u";
pub const UINT_LEAST32_FMTx__ = "x";
pub const UINT_LEAST32_FMTX__ = "X";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const INT_FAST32_FMTd__ = "d";
pub const INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_FAST32_FMTo__ = "o";
pub const UINT_FAST32_FMTu__ = "u";
pub const UINT_FAST32_FMTx__ = "x";
pub const UINT_FAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const INT_LEAST64_FMTd__ = "ld";
pub const INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_LEAST64_FMTo__ = "lo";
pub const UINT_LEAST64_FMTu__ = "lu";
pub const UINT_LEAST64_FMTx__ = "lx";
pub const UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const INT_FAST64_FMTd__ = "ld";
pub const INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_FMTo__ = "lo";
pub const UINT_FAST64_FMTu__ = "lu";
pub const UINT_FAST64_FMTx__ = "lx";
pub const UINT_FAST64_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = "";
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = "";
pub const __FLT16_HAS_QUIET_NAN__ = "";
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = "";
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = "";
pub const __FLT_HAS_QUIET_NAN__ = "";
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = "";
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = "";
pub const __DBL_HAS_QUIET_NAN__ = "";
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = "";
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = "";
pub const __LDBL_HAS_QUIET_NAN__ = "";
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __FLT_EVAL_METHOD__ = @as(c_int, 0);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __pic__ = @as(c_int, 2);
pub const __PIC__ = @as(c_int, 2);
pub const __GLIBC_MINOR__ = @as(c_int, 43);
pub const PORTAUDIO_H = "";
pub inline fn paMakeVersionNumber(major: anytype, minor: anytype, subminor: anytype) @TypeOf((((major & @as(c_int, 0xFF)) << @as(c_int, 16)) | ((minor & @as(c_int, 0xFF)) << @as(c_int, 8))) | (subminor & @as(c_int, 0xFF))) {
    _ = &major;
    _ = &minor;
    _ = &subminor;
    return (((major & @as(c_int, 0xFF)) << @as(c_int, 16)) | ((minor & @as(c_int, 0xFF)) << @as(c_int, 8))) | (subminor & @as(c_int, 0xFF));
}
pub const paNoDevice = __helpers.cast(PaDeviceIndex, -@as(c_int, 1));
pub const paUseHostApiSpecificDeviceSpecification = __helpers.cast(PaDeviceIndex, -@as(c_int, 2));
pub const paFloat32 = __helpers.cast(PaSampleFormat, @as(c_int, 0x00000001));
pub const paInt32 = __helpers.cast(PaSampleFormat, @as(c_int, 0x00000002));
pub const paInt24 = __helpers.cast(PaSampleFormat, @as(c_int, 0x00000004));
pub const paInt16 = __helpers.cast(PaSampleFormat, @as(c_int, 0x00000008));
pub const paInt8 = __helpers.cast(PaSampleFormat, @as(c_int, 0x00000010));
pub const paUInt8 = __helpers.cast(PaSampleFormat, @as(c_int, 0x00000020));
pub const paCustomFormat = __helpers.cast(PaSampleFormat, __helpers.promoteIntLiteral(c_int, 0x00010000, .hex));
pub const paNonInterleaved = __helpers.cast(PaSampleFormat, __helpers.promoteIntLiteral(c_int, 0x80000000, .hex));
pub const paFormatIsSupported = @as(c_int, 0);
pub const paFramesPerBufferUnspecified = @as(c_int, 0);
pub const paNoFlag = __helpers.cast(PaStreamFlags, @as(c_int, 0));
pub const paClipOff = __helpers.cast(PaStreamFlags, @as(c_int, 0x00000001));
pub const paDitherOff = __helpers.cast(PaStreamFlags, @as(c_int, 0x00000002));
pub const paNeverDropInput = __helpers.cast(PaStreamFlags, @as(c_int, 0x00000004));
pub const paPrimeOutputBuffersUsingStreamCallback = __helpers.cast(PaStreamFlags, @as(c_int, 0x00000008));
pub const paPlatformSpecificFlags = __helpers.cast(PaStreamFlags, __helpers.promoteIntLiteral(c_int, 0xFFFF0000, .hex));
pub const paInputUnderflow = __helpers.cast(PaStreamCallbackFlags, @as(c_int, 0x00000001));
pub const paInputOverflow = __helpers.cast(PaStreamCallbackFlags, @as(c_int, 0x00000002));
pub const paOutputUnderflow = __helpers.cast(PaStreamCallbackFlags, @as(c_int, 0x00000004));
pub const paOutputOverflow = __helpers.cast(PaStreamCallbackFlags, @as(c_int, 0x00000008));
pub const paPrimingOutput = __helpers.cast(PaStreamCallbackFlags, @as(c_int, 0x00000010));
