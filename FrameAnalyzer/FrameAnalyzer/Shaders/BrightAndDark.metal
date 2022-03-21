//
//  BrightAndDark.metal
//  asd
//
//  Created by Kirill Galuzo on 19.09.2022.
//

#include <metal_stdlib>
using namespace metal;

struct BrightAndDarkParameters
{
	float brightThreshold;
	float darkThreshhold;
};

kernel void calculateBrightAndDarkPixelsCount(texture2d<float, access::read> inTexture [[texture(0)]],
											  volatile device uint *darkPixelCounter [[buffer(0)]],
											  volatile device uint *brightPixelCounter [[buffer(1)]],
											  constant BrightAndDarkParameters& params [[buffer(2)]],
											  uint2 id [[thread_position_in_grid]])
{
	float3 rgbValue = inTexture.read(id).rgb;
//	float grayPixelValue = 0.299 * rgbValue.r + 0.587 * rgbValue.g + 0.114 * rgbValue.b;
	float grayPixelValue = (rgbValue.r + rgbValue.g + rgbValue.b) / 3;

	if (grayPixelValue < params.darkThreshhold) {
		device atomic_uint *atomicDarkPixelCounter = (device atomic_uint *)darkPixelCounter;
		atomic_fetch_add_explicit(atomicDarkPixelCounter, 1, memory_order_relaxed);
	}
	if (grayPixelValue > params.brightThreshold) {
		device atomic_uint *atomicBrightPixelCounter = (device atomic_uint *)brightPixelCounter;
		atomic_fetch_add_explicit(atomicBrightPixelCounter, 1, memory_order_relaxed);
	}
};
