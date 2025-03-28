/*
HOW TO USE:

	In exactly one translation unit (.c or .cpp file), #define MSF_GIF_IMPL before including the header, like so:

	#define MSF_GIF_IMPL
	#include "msf_gif.h"

	Everywhere else, just include the header like normal.


USAGE EXAMPLE:

	c_int width = 480, height = 320, centisecondsPerFrame = 5, quality = 16;
	MsfGifState gifState = {}
	// msf_gif_bgra_flag = true; //optionally, set this flag if your pixels are in BGRA format instead of RGBA
	// msf_gif_alpha_threshold = 128; //optionally, enable transparency (see function documentation below for details)
	msf_gif_begin(&gifState, width, height);
	msf_gif_frame(&gifState, ..., centisecondsPerFrame, quality, width * 4); //frame 1
	msf_gif_frame(&gifState, ..., centisecondsPerFrame, quality, width * 4); //frame 2
	msf_gif_frame(&gifState, ..., centisecondsPerFrame, quality, width * 4); //frame 3, etc...
	MsfGifResult result = msf_gif_end(&gifState);
	if (result.data) {
		FILE * fp = fopen("MyGif.gif", "wb");
		fwrite(result.data, result.dataSize, 1, fp);
		fclose(fp);
	}
	msf_gif_free(result);

Detailed function documentation can be found in the header section below.


ERROR HANDLING:

	If memory allocation fails, the functions will signal the error via their return values.
	If one function call fails, the library will free all of its allocations,
	and all subsequent calls will safely no-op and return 0 until the next call to `msf_gif_begin()`.
	Therefore, it's safe to check only the return value of `msf_gif_end()`.


REPLACING MALLOC:

	This library uses malloc+realloc+free internally for memory allocation.
	To facilitate integration with custom memory allocators, these calls go through macros, which can be redefined.
	The expected function signature equivalents of the macros are as follows:

	void* MSF_GIF_MALLOC(void* context, size_t newSize)
	void* MSF_GIF_REALLOC(void* context, void* oldMemory, size_t oldSize, size_t newSize)
	void MSF_GIF_FREE(void* context, void* oldMemory, size_t oldSize)

	If your allocator needs a context pointer, you can set the `customAllocatorContext` field of the MsfGifState struct
	before calling msf_gif_begin(), and it will be passed to all subsequent allocator macro calls.

	The maximum number of bytes the library will allocate to encode a single gif is bounded by the following formula:
	`(2 * 1024 * 1024) + (width * height * 8) + ((1024 + width * height * 1.5) * 3 * frameCount)`
	The peak heap memory usage in bytes, if using a general-purpose heap allocator, is bounded by the following formula:
	`(2 * 1024 * 1024) + (width * height * 9.5) + 1024 + (16 * frameCount) + (2 * sizeOfResultingGif)


See end of file for license information.
*/

using System;
using System.Interop;

namespace msf_gif;

public static class msf_gif
{
	typealias size_t = uint;
	typealias uint8_t = uint8;
	typealias uint16_t = uint16;
	typealias uint32_t = uint32;
	typealias uint64_t = uint64;
	typealias int8_t = int8;
	typealias int16_t = int16;
	typealias int32_t = int32;
	typealias int64_t = int64;

	[CRepr]
	public struct MsfGifResult
	{
		public void* data;
		public size_t dataSize;

		size_t allocSize; //internal use
		void* contextPointer; //internal use
	}

	[CRepr]
	public struct MsfCookedFrame
	{ //internal use
		public uint32_t* pixels;
		public c_int depth, count, rbits, gbits, bbits;
	}

	[CRepr]
	public struct MsfGifBuffer
	{ //internal use
		MsfGifBuffer* next;
		size_t size;
		uint8_t[1] data;
	}

	public function size_t MsfGifFileWriteFunc(void* buffer, size_t size, size_t count, void* stream);

	[CRepr]
	public struct MsfGifState
	{ //internal use
		MsfGifFileWriteFunc fileWriteFunc;
		void* fileWriteData;
		MsfCookedFrame previousFrame;
		MsfCookedFrame currentFrame;
		int16_t* lzwMem;
		uint8_t* tlbMem;
		uint8_t* usedMem;
		MsfGifBuffer* listHead;
		MsfGifBuffer* listTail;
		c_int width, height;
		void* customAllocatorContext;
		c_int framesSubmitted; //needed for transparency to work correctly (because we reach into the previous frame)
	}

	/**
	* @param width                Image width in pixels.
	* @param height               Image height in pixels.
	* @return                     Non-zero on success, 0 on error.
	*/
	[CLink] public static extern c_int msf_gif_begin(MsfGifState* handle, c_int width, c_int height);

	/**
	* @param pixelData            Pointer to raw framebuffer data. Rows must be contiguous in memory, in RGBA8 format
	*                             (or BGRA8 if you have set `msf_gif_bgra_flag = true`).
	*                             Note: This function does NOT free `pixelData`. You must free it yourself afterwards.
	* @param centiSecondsPerFrame How many hundredths of a second this frame should be displayed for.
	*                             Note: This being specified in centiseconds is a limitation of the GIF format.
	* @param quality              This parameter limits the maximum color accuracy for quantization.
	*                             Actual color accuracy varies dynamically based on how many colors are used in the frame.
	*                             `quality` is clamped between 1 and 16. The recommended default is 16.
	*                             Lowering this value can result in smaller gifs and slightly faster exports,
	*                             but the resulting gifs may look noticeably worse with a more extreme dither pattern.
	* @param pitchInBytes         The number of bytes from the beginning of one row of pixels to the beginning of the next.
	*                             If you want to flip the image, just pass in a negative pitch.
	* @return                     Non-zero on success, 0 on error.
	*/
	[CLink] public static extern c_int msf_gif_frame(MsfGifState* handle, uint8_t* pixelData, c_int centiSecondsPerFrame, c_int quality, c_int pitchInBytes);

	/**
	* @return                     A block of memory containing the gif file data, or NULL on error.
	*                             You are responsible for freeing this via `msf_gif_free()`.
	*/
	[CLink] public static extern MsfGifResult msf_gif_end(MsfGifState* handle);

	/**
	* @param result                The MsfGifResult struct, verbatim as it was returned from `msf_gif_end()`.
	*/
	[CLink] public static extern void msf_gif_free(MsfGifResult result);

	//The gif format only supports 1-bit transparency, meaning a pixel will either be fully transparent or fully opaque.
	//Pixels with an alpha value less than the alpha threshold will be treated as transparent.
	//To enable exporting transparent gifs, set it to a value between 1 and 255 (inclusive) before calling msf_gif_frame().
	//Setting it to 0 causes the alpha channel to be ignored. Its initial value is 0.
	// extern c_int msf_gif_alpha_threshold;

	//Set `msf_gif_bgra_flag = true` before calling `msf_gif_frame()` if your pixels are in BGRA byte order instead of RBGA.
	// extern c_int msf_gif_bgra_flag;



	//TO-FILE FUNCTIONS
	//These functions are equivalent to the ones above, but they write results to a file incrementally,
	//instead of building a buffer in memory. This can result in lower memory usage when saving large gifs,
	//because memory usage is bounded by only the size of a single frame, and is not dependent on the number of frames.
	//There is currently no reason to use these unless you are on a memory-constrained platform.
	//If in doubt about which API to use, for now you should use the normal (non-file) functions above.
	//The signature of MsfGifFileWriteFunc matches fwrite for convenience, so that you can use the C file API like so:
	//  FILE * fp = fopen("MyGif.gif", "wb");
	//  msf_gif_begin_to_file(&handle, width, height, (MsfGifFileWriteFunc) fwrite, (void*) fp);
	//  msf_gif_frame_to_file(...)
	//  msf_gif_end_to_file(&handle);
	//  fclose(fp);
	//If you use a custom file write function, you must take care to return the same values that fwrite() would return.
	//Note that all three functions will potentially write to the file.
	[CLink] public static extern c_int msf_gif_begin_to_file(MsfGifState* handle, c_int width, c_int height, MsfGifFileWriteFunc func, void* filePointer);
	[CLink] public static extern c_int msf_gif_frame_to_file(MsfGifState* handle, uint8_t* pixelData, c_int centiSecondsPerFrame, c_int quality, c_int pitchInBytes);
	[CLink] public static extern c_int msf_gif_end_to_file(MsfGifState* handle); //returns 0 on error and non-zero on success
}