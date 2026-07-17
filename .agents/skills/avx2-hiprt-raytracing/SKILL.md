---
name: "avx2-hiprt-raytracing"
description: "Guidelines and techniques for AVX2 and OpenRT HIP (Radeon ProRender) ray tracing in Source Engine (vrad/vvis)."
---

# AVX2 & HIPRT Ray Tracing in Source Engine

This skill provides architectural guidelines for porting legacy scalar or SSE (4-wide) raycasting code (like `vrad` or `vvis`) to modern AVX2 (8-wide) and hardware-accelerated HIPRT.

## 1. AVX2 Vectorization (EightRays)

Legacy Source Engine uses `FourRays` and `fltx4` (`__m128`). The modern upgrade uses `EightRays` and `fltx8` (`__m256`).

### Memory Layout (SoA vs AoS)
- **Rule:** Always use Structure of Arrays (SoA).
- Instead of an array of 8 `Ray` objects, use 8-wide vectors for `origin.x`, `origin.y`, `origin.z`, `direction.x`, etc.
- Example:
  ```cpp
  struct EightRays {
      fltx8 ox, oy, oz; // Origins
      fltx8 dx, dy, dz; // Directions
  };
  ```

### Branching and Masks
- **Rule:** Ray tracing algorithms (like Möller-Trumbore triangle intersection or Smits' box intersection) must be **branchless** within the SIMD lanes.
- Use `CmpEqSIMD`, `CmpGtSIMD` to generate masks.
- Use `AndSIMD`, `AndNotSIMD`, `OrSIMD` to selectively update hit distances or IDs only for active rays in the packet.
- Only exit the traversal loop early if the combined bitmask of all 8 rays (`TestSignSIMD`) indicates all rays have either hit a blocking surface or terminated.

### Memory Bandwidth
- AVX2 is often bandwidth-bound rather than compute-bound. Ensure your BVH nodes are padded and aligned to 32 bytes (or 64 bytes for cache lines) to optimize `LoadAlignedSIMD` / `_mm256_load_ps`.

## 2. HIPRT (Hardware Ray Tracing on AMD / OpenRT)

For pure GPU offloading, we use Radeon ProRender's HIPRT SDK.

### Context Initialization
- `hiprtContext` must be created by wrapping the primary `HIP` context.
- Keep the CPU fallback (AVX2) alive for developers without discrete AMD RDNA2+ hardware.

### Geometry and Scenes (BLAS / TLAS)
- **BLAS (Bottom-Level Acceleration Structure):** Build these over static map props or BSP leaves (`dleaf_t`).
- **TLAS (Top-Level Acceleration Structure):** Build the scene hierarchy representing the entire BSP tree and dynamic entities.

### Traversal in Kernels
- **Rule:** Do NOT mix complex shading with traversal. Use `hiprt_device.h` functions to perform intersection queries inside minimal HIP kernels.
- Send the hit results back to global memory or handle lightmap accumulation directly via atomic operations.

## 3. Workflow for Upgrading `vrad`
1. Replace `fltx4` with `fltx8` in `trace.cpp` / `vrad.cpp`.
2. Convert `FourRays` to `EightRays`.
3. Rewrite `CCoverageCount` masks to process 8 lanes.
4. (Phase 2) Bridge the `dbrush_t` and `dleaf_t` structures into `hiprtGeometryBuildInput` to generate hardware BVHs.
