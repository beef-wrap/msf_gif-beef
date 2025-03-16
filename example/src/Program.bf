using System;
using System.Collections;
using System.Diagnostics;
using System.IO;
using System.Interop;
using System.Text;

using static msf_gif.msf_gif;
using static stb.stb_image;

namespace example;

static class Program
{
	typealias FILE = void*;

	[CLink] public static extern FILE* fopen(char8* path, char8* mode);
	[CLink] public static extern void fwrite(void* data, uint len, int b, FILE* file);
	[CLink] public static extern void fclose(FILE* file);

	static uint8[?] data = .();

	static int Main(params String[] args)
	{
		c_int x = ?, y = ?, n = ?;
		c_uchar* data = stbi_load("test.png", &x, &y, &n, 0);
		// ... process data if not NULL ...
		// ... x = width, y = height, n = # 8-bit components per pixel ...
		// ... replace '0' with '1'..'4' to force that many components per pixel
		// ... but 'n' will always be the number that it would have been if you said 0


		c_int width = x, height = y, centisecondsPerFrame = 5, quality = 16;
		MsfGifState gifState = .();
		// msf_gif_bgra_flag = true; //optionally, set this flag if your pixels are in BGRA format instead of RGBA
		// msf_gif_alpha_threshold = 128; //optionally, enable transparency (see documentation in header for details)
		msf_gif_begin(&gifState, width, height);
		msf_gif_frame(&gifState, data, centisecondsPerFrame, quality, width * 4); //frame 1
		msf_gif_frame(&gifState, data, centisecondsPerFrame, quality, width * 4); //frame 2
		msf_gif_frame(&gifState, data, centisecondsPerFrame, quality, width * 4); //frame 3, etc...
		MsfGifResult result = msf_gif_end(&gifState);
		if (result.data != null)
		{
			FILE* fp = fopen("MyGif.gif", "wb");
			fwrite(result.data, result.dataSize, 1, fp);
			fclose(fp);
		}
		msf_gif_free(result);

		stbi_image_free(data);

		return 0;
	}
}