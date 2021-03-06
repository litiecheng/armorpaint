package arm.renderpath;

import iron.RenderPath;
import armory.renderpath.Inc;

class RenderPathDeferred {

	#if (rp_renderer == "Deferred")

	static var path:RenderPath;

	#if (rp_gi != "Off")
	static var voxels = "voxels";
	static var voxelsLast = "voxels";
	#end

	public static function init(_path:RenderPath) {

		path = _path;

		armory.renderpath.RenderPathDeferred.init(path);

		// Paint
		{
			path.createDepthBuffer("paintdb", "DEPTH16");
		}

		var w = 1;
		for (i in 0...8)
		{
			var t = new RenderTargetRaw();
			t.name = "texpaint_colorid" + i;
			t.width = w;
			t.height = w;
			t.format = 'RGBA32';
			path.createRenderTarget(t);
			w *= 2;
		}

		path.loadShader("shader_datas/max_luminance_pass/max_luminance_pass");
		path.loadShader("shader_datas/copy_mrt3_pass/copy_mrt3_pass");
		path.loadShader("shader_datas/copy_mrt4_pass/copy_mrt4_pass");

		{ // Material preview
			{
				var t = new RenderTargetRaw();
				t.name = "texpreview";
				t.width = 1;
				t.height = 1;
				t.format = 'RGBA32';
				path.createRenderTarget(t);
			}

			{
				path.createDepthBuffer("mmain", "DEPTH24");

				var t = new RenderTargetRaw();
				t.name = "mtex";
				t.width = 100;
				t.height = 100;
				t.format = Inc.getHdrFormat();
				t.scale = Inc.getSuperSampling();
				t.depth_buffer = "mmain";
				path.createRenderTarget(t);
			}

			{
				var t = new RenderTargetRaw();
				t.name = "mbuf";
				t.width = 100;
				t.height = 100;
				t.format = Inc.getHdrFormat();
				t.scale = Inc.getSuperSampling();
				path.createRenderTarget(t);
			}

			{
				var t = new RenderTargetRaw();
				t.name = "mgbuffer0";
				t.width = 100;
				t.height = 100;
				t.format = "RGBA64";
				t.scale = Inc.getSuperSampling();
				t.depth_buffer = "mmain";
				path.createRenderTarget(t);
			}

			{
				var t = new RenderTargetRaw();
				t.name = "mgbuffer1";
				t.width = 100;
				t.height = 100;
				t.format = "RGBA64";
				t.scale = Inc.getSuperSampling();
				path.createRenderTarget(t);
			}

			#if rp_gbuffer2
			{
				var t = new RenderTargetRaw();
				t.name = "mgbuffer2";
				t.width = 100;
				t.height = 100;
				t.format = "RGBA64";
				t.scale = Inc.getSuperSampling();
				path.createRenderTarget(t);
			}
			#end

			#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
			{
				var t = new RenderTargetRaw();
				t.name = "mbufa";
				t.width = 100;
				t.height = 100;
				t.format = "RGBA32";
				t.scale = Inc.getSuperSampling();
				path.createRenderTarget(t);
			}
			{
				var t = new RenderTargetRaw();
				t.name = "mbufb";
				t.width = 100;
				t.height = 100;
				t.format = "RGBA32";
				t.scale = Inc.getSuperSampling();
				path.createRenderTarget(t);
			}
			#end
		}
		//
	}

	// Paint
	static var initVoxels = true;
	public static function drawShadowMap() {
		#if (rp_shadowmap)
		@:privateAccess Inc.pointIndex = 0;
		@:privateAccess Inc.spotIndex = 0;
		for (l in iron.Scene.active.lights) {
			if (!l.visible || !l.data.raw.cast_shadow) continue;
			path.light = l;
			var shadowmap = @:privateAccess Inc.getShadowMap(l);
			var faces = l.data.raw.shadowmap_cube ? 6 : 1;
			for (i in 0...faces) {
				if (faces > 1) path.currentFace = i;
				path.setTarget(shadowmap);
				// Paint
				if (arm.UITrait.inst.paintHeight) {
					var tid = arm.UITrait.inst.layers[0].id;
					path.bindTarget("texpaint_opt" + tid, "texpaint_opt");
				}
				//
				path.clearTarget(null, 1.0);
				path.drawMeshes("shadowmap");
			}
			path.currentFace = -1;

			if (l.data.raw.type == "point") @:privateAccess Inc.pointIndex++;
			else if (l.data.raw.type == "spot") @:privateAccess Inc.spotIndex++;
		}
		#end
	}

	@:access(iron.RenderPath)
	public static function commands() {

		// Paint
		if (arm.App.realw() == 0 || arm.App.realh() == 0) return;

		if (!arm.UITrait.inst.dirty()) {
			path.setTarget("");
			path.bindTarget("bufb", "tex");
			path.drawShader("shader_datas/copy_pass/copy_pass");
			return;
		}

		var tid = arm.UITrait.inst.selectedLayer.id;

		if (arm.UITrait.inst.pushUndo) {
			var i = arm.UITrait.inst.undoI;
			if (arm.UITrait.inst.paintHeight) {
				path.setTarget("texpaint_undo" + i, ["texpaint_nor_undo" + i, "texpaint_pack_undo" + i, "texpaint_opt_undo" + i]);
			}
			else {
				path.setTarget("texpaint_undo" + i, ["texpaint_nor_undo" + i, "texpaint_pack_undo" + i]);
			}
			
			path.bindTarget("texpaint" + tid, "tex0");
			path.bindTarget("texpaint_nor" + tid, "tex1");
			path.bindTarget("texpaint_pack" + tid, "tex2");
			if (arm.UITrait.inst.paintHeight) {
				path.bindTarget("texpaint_opt" + tid, "tex3");
				path.drawShader("shader_datas/copy_mrt4_pass/copy_mrt4_pass");
			}
			else {
				path.drawShader("shader_datas/copy_mrt3_pass/copy_mrt3_pass");
			}
			arm.UITrait.inst.undoLayers[arm.UITrait.inst.undoI].targetObject = arm.UITrait.inst.paintObject;
			arm.UITrait.inst.undoLayers[arm.UITrait.inst.undoI].targetLayer = arm.UITrait.inst.selectedLayer;
			arm.UITrait.inst.undoI = (arm.UITrait.inst.undoI + 1) % arm.UITrait.inst.C.undo_steps;
			if (arm.UITrait.inst.undos < arm.UITrait.inst.C.undo_steps) arm.UITrait.inst.undos++;
			arm.UITrait.inst.redos = 0;
			arm.UITrait.inst.pushUndo = false;
		}

		if (arm.UITrait.inst.depthDirty()) {
			path.setTarget("texpaint" + tid);
			path.clearTarget(null, 1.0);
			path.drawMeshes("depth"); // TODO: CHECK DEPTH EXPORT
		}

		if (arm.UITrait.inst.paintDirty()) {
			if (arm.UITrait.inst.brushType == 4) { // Pick Color Id
				path.setTarget("texpaint_colorid7");
				path.clearTarget(0xff000000);
				path.bindTarget("_paintdb", "paintdb");
				path.drawMeshes("paint");
				// Extract picked color to 1x1 texture
				for (i in 0...7) {
					var j = 7 - i;
					path.setTarget("texpaint_colorid" + (j - 1));
					path.bindTarget("texpaint_colorid" + j, "tex");
					path.drawShader("shader_datas/max_luminance_pass/max_luminance_pass");
				}
			}
			else {
				if (arm.UITrait.inst.brushType == 3) { // Bake AO
					if (initVoxels) {
						initVoxels = false;
						var t = new RenderTargetRaw();
						t.name = "voxels";
						t.format = "R8";
						t.width = 256;
						t.height = 256;
						t.depth = 256;
						t.is_image = true;
						t.mipmaps = true;
						path.createRenderTarget(t);
					}
					path.clearImage("voxels", 0x00000000);
					path.setTarget("");
					path.setViewport(256, 256);
					path.bindTarget("voxels", "voxels");
					path.drawMeshes("voxel");
					path.generateMipmaps("voxels");
				}
				if (arm.UITrait.inst.paintHeight) {
					path.setTarget("texpaint" + tid, ["texpaint_nor" + tid, "texpaint_pack" + tid, "texpaint_opt" + tid]);
				}
				else {
					path.setTarget("texpaint" + tid, ["texpaint_nor" + tid, "texpaint_pack" + tid]);
				}
				path.bindTarget("_paintdb", "paintdb");
				if (arm.UITrait.inst.brushType == 3) { // Bake AO
					path.bindTarget("voxels", "voxels");
				}
				if (arm.UITrait.inst.colorIdPicked) {
					path.bindTarget("texpaint_colorid0", "texpaint_colorid0");
				} 
				path.drawMeshes("paint");
			}
		}
		//

		#if rp_dynres
		{
			DynamicResolutionScale.run(path);
		}
		#end

		path.setTarget("gbuffer0"); // Only clear gbuffer0
		#if (rp_background == "Clear")
		{
			path.clearTarget(-1, 1.0);
		}
		#else
		{
			path.clearTarget(null, 1.0);
		}
		#end

		#if rp_gbuffer2
		{
			path.setTarget("gbuffer2");
			path.clearTarget(0xff000000);
			path.setTarget("gbuffer0", ["gbuffer1", "gbuffer2"]);
		}
		#else
		{
			path.setTarget("gbuffer0", ["gbuffer1"]);
		}
		#end

		// Paint
		tid = arm.UITrait.inst.layers[0].id;
		path.bindTarget("texpaint" + tid, "texpaint");
		path.bindTarget("texpaint_nor" + tid, "texpaint_nor");
		path.bindTarget("texpaint_pack" + tid, "texpaint_pack");
		if (arm.UITrait.inst.paintHeight) path.bindTarget("texpaint_opt" + tid, "texpaint_opt");
		for (i in 1...arm.UITrait.inst.layers.length) {
			tid = arm.UITrait.inst.layers[i].id;
			path.bindTarget("texpaint" + tid, "texpaint" + tid);
			path.bindTarget("texpaint_nor" + tid, "texpaint_nor" + tid);
			path.bindTarget("texpaint_pack" + tid, "texpaint_pack" + tid);
			if (arm.UITrait.inst.paintHeight) path.bindTarget("texpaint_opt" + tid, "texpaint_opt" + tid);
		}
		//

		#if rp_stereo
		{
			path.drawStereo(drawMeshes);
		}
		#else
		{
			RenderPathCreator.drawMeshes();
		}
		#end

		#if rp_decals
		{
			path.setDepthFrom("gbuffer0", "gbuffer1"); // Unbind depth so we can read it
			path.depthToRenderTarget.set("main", path.renderTargets.get("tex"));
			path.setTarget("gbuffer0", ["gbuffer1"]);
			
			path.bindTarget("_main", "gbufferD");
			path.drawDecals("decal");
			
			path.setDepthFrom("gbuffer0", "tex"); // Re-bind depth
			path.depthToRenderTarget.set("main", path.renderTargets.get("gbuffer0"));
		}
		#end

		#if (rp_ssr_half || rp_ssgi_half)
		path.setTarget("half");
		path.bindTarget("_main", "texdepth");
		path.drawShader("shader_datas/downsample_depth/downsample_depth");
		#end

		#if ((rp_ssgi == "RTGI") || (rp_ssgi == "RTAO"))
		{
			if (armory.data.Config.raw.rp_ssgi != false) {
				path.setTarget("singlea");
				#if rp_ssgi_half
				path.bindTarget("half", "gbufferD");
				#else
				path.bindTarget("_main", "gbufferD");
				#end
				path.bindTarget("gbuffer0", "gbuffer0");
				// #if (rp_ssgi == "RTGI")
				// path.bindTarget("gbuffer1", "gbuffer1");
				// #end
				path.drawShader("shader_datas/ssgi_pass/ssgi_pass");

				path.setTarget("singleb");
				path.bindTarget("singlea", "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/blur_edge_pass/blur_edge_pass_x");

				path.setTarget("singlea");
				path.bindTarget("singleb", "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/blur_edge_pass/blur_edge_pass_y");
			}
		}	
		#elseif (rp_ssgi == "SSAO")
		{
			if (armory.data.Config.raw.rp_ssgi != false) {
				path.setTarget("singlea");
				path.bindTarget("_main", "gbufferD");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/ssao_pass/ssao_pass");

				path.setTarget("singleb");
				path.bindTarget("singlea", "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/blur_edge_pass/blur_edge_pass_x");

				path.setTarget("singlea");
				path.bindTarget("singleb", "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/blur_edge_pass/blur_edge_pass_y");
			}
		}
		#end

		// Voxels
		#if (rp_gi != "Off")
		var relight = false;
		if (armory.data.Config.raw.rp_gi != false)
		{
			var voxelize = path.voxelize();

			#if arm_voxelgi_temporal
			voxelize = ++RenderPathCreator.voxelFrame % RenderPathCreator.voxelFreq == 0;

			if (voxelize) {
				voxels = voxels == "voxels" ? "voxelsB" : "voxels";
				voxelsLast = voxels == "voxels" ? "voxelsB" : "voxels";
			}
			#end

			if (voxelize) {
				var res = Inc.getVoxelRes();

				#if (rp_gi == "Voxel GI")
				var voxtex = "voxelsOpac";
				#else
				var voxtex = voxels;
				#end

				path.clearImage(voxtex, 0x00000000);
				path.setTarget("");
				path.setViewport(res, res);
				path.bindTarget(voxtex, "voxels");
				path.drawMeshes("voxel");

				relight = true;
			}

			#if ((rp_gi == "Voxel GI") && (rp_voxelgi_relight))
			// Relight if light was moved
			for (light in iron.Scene.active.lights) {
				if (light.transform.diff()) { relight = true; break; }
			}
			#end

			if (relight) {
				#if (rp_gi == "Voxel GI")
					// Inc.computeVoxelsBegin();
					// for (i in 0...lights.length) Inc.computeVoxels(i); // Redraws SM
					// Inc.computeVoxelsEnd();
					#if (rp_gi_bounces)
					voxels = "voxelsBounce";
					#end
				#else
				path.generateMipmaps(voxels); // AO
				#end
			}
		}
		#end

		// ---
		// Deferred light
		// ---
		var lights = iron.Scene.active.lights;
		
		// #if (rp_gi == "Voxel GI")
		// if (relight) Inc.computeVoxelsBegin();
		// #end
		// #if (rp_gi == "Voxel GI")
		// if (relight) Inc.computeVoxels(i);
		// #end
		// #if (rp_gi == "Voxel GI")
		// if (relight) Inc.computeVoxelsEnd();
		// #end

		#if (rp_shadowmap)
		// Inc.drawShadowMap();
		drawShadowMap(); // Paint
		#end

		path.setDepthFrom("tex", "gbuffer1"); // Unbind depth so we can read it
		path.setTarget("tex");
		path.bindTarget("_main", "gbufferD");
		path.bindTarget("gbuffer0", "gbuffer0");
		path.bindTarget("gbuffer1", "gbuffer1");
		// 	#if rp_gbuffer2_direct
		// 	path.bindTarget("gbuffer2", "gbuffer2");
		// 	#end
		#if (rp_ssgi != "Off")
		{
			if (armory.data.Config.raw.rp_ssgi != false) {
				path.bindTarget("singlea", "ssaotex");
			}
			else {
				path.bindTarget("empty_white", "ssaotex");
			}
		}
		#end
		var voxelao_pass = false;
		#if (rp_gi != "Off")
		if (armory.data.Config.raw.rp_gi != false)
		{
			#if (rp_gi == "Voxel AO")
			voxelao_pass = true;
			#end
			path.bindTarget(voxels, "voxels");
			#if arm_voxelgi_temporal
			{
				path.bindTarget(voxelsLast, "voxelsLast");
			}
			#end
		}
		#end

		#if rp_shadowmap
		{
			// if (path.lightCastShadow()) {
				#if rp_soft_shadows
				path.bindTarget("visa", "svisibility");
				#else
				Inc.bindShadowMap();
				#end
			// }
		}
		#end
		
		#if rp_material_solid
		path.drawShader("shader_datas/deferred_light_solid/deferred_light");
		#elseif rp_material_mobile
		path.drawShader("shader_datas/deferred_light_mobile/deferred_light");
		#else
		voxelao_pass ?
			path.drawShader("shader_datas/deferred_light/deferred_light_VoxelAOvar") :
			path.drawShader("shader_datas/deferred_light/deferred_light");
		#end
		
		#if rp_probes
		if (!path.isProbe) {
			var probes = iron.Scene.active.probes;
			for (i in 0...probes.length) {
				var p = probes[i];
				if (!p.visible || p.culled) continue;
				path.currentProbeIndex = i;
				path.setTarget("tex");
				path.bindTarget("_main", "gbufferD");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.bindTarget("gbuffer1", "gbuffer1");
				path.bindTarget(p.raw.name, "probeTex");
				if (p.data.raw.type == "planar") {
					path.drawVolume(p, "shader_datas/probe_planar/probe_planar");
				}
				else if (p.data.raw.type == "cubemap") {
					path.drawVolume(p, "shader_datas/probe_cubemap/probe_cubemap");
				}
			}
		}
		#end

		// #if rp_volumetriclight
		// {
		// 	path.setTarget("bufvola");
		// 	path.bindTarget("_main", "gbufferD");
		// 	Inc.bindShadowMap();
		// 	if (path.lightIsSun()) {
		// 		path.drawShader("shader_datas/volumetric_light_quad/volumetric_light_quad");
		// 	}
		// 	else {
		// 		path.drawLightVolume("shader_datas/volumetric_light/volumetric_light");
		// 	}

		// 	path.setTarget("bufvolb");
		// 	path.bindTarget("bufvola", "tex");
		// 	path.drawShader("shader_datas/blur_bilat_pass/blur_bilat_pass_x");

		// 	path.setTarget("tex");
		// 	path.bindTarget("bufvolb", "tex");
		// 	path.drawShader("shader_datas/blur_bilat_blend_pass/blur_bilat_blend_pass_y");
		// }
		// #end

		#if (rp_background == "World")
		{
			path.setTarget("tex"); // Re-binds depth
			path.drawSkydome("shader_datas/world_pass/world_pass");
		}
		#end

		#if rp_ocean
		{
			path.setTarget("tex");
			path.bindTarget("_main", "gbufferD");
			path.drawShader("shader_datas/water_pass/water_pass");
		}
		#end

		#if rp_blending
		{
			path.drawMeshes("blend");
		}
		#end

		#if rp_translucency
		{
			var hasLight = iron.Scene.active.lights.length > 0;
			if (hasLight) Inc.drawTranslucency("tex");
		}
		#end

		#if rp_bloom
		{
			if (armory.data.Config.raw.rp_bloom != false) {
				path.setTarget("bloomtex");
				path.bindTarget("tex", "tex");
				path.drawShader("shader_datas/bloom_pass/bloom_pass");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("bloomtex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y");

				path.setTarget("bloomtex2");
				path.bindTarget("bloomtex", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_x");

				path.setTarget("tex");
				path.bindTarget("bloomtex2", "tex");
				path.drawShader("shader_datas/blur_gaus_pass/blur_gaus_pass_y_blend");
			}
		}
		#end

		#if rp_sss
		{
			path.setTarget("buf");
			path.bindTarget("tex", "tex");
			path.bindTarget("_main", "gbufferD");
			path.bindTarget("gbuffer2", "gbuffer2");
			path.drawShader("shader_datas/sss_pass/sss_pass_x");

			path.setTarget("tex");
			// TODO: can not bind tex
			path.bindTarget("tex", "tex");
			path.bindTarget("_main", "gbufferD");
			path.bindTarget("gbuffer2", "gbuffer2");
			path.drawShader("shader_datas/sss_pass/sss_pass_y");
		}
		#end

		#if rp_ssr
		{
			if (armory.data.Config.raw.rp_ssr != false) {
				#if rp_ssr_half
				var targeta = "ssra";
				var targetb = "ssrb";
				#else
				var targeta = "buf";
				var targetb = "gbuffer1";
				#end

				path.setTarget(targeta);
				path.bindTarget("tex", "tex");
				#if rp_ssr_half
				path.bindTarget("half", "gbufferD");
				#else
				path.bindTarget("_main", "gbufferD");
				#end
				path.bindTarget("gbuffer0", "gbuffer0");
				path.bindTarget("gbuffer1", "gbuffer1");
				path.drawShader("shader_datas/ssr_pass/ssr_pass");

				path.setTarget(targetb);
				path.bindTarget(targeta, "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/blur_adaptive_pass/blur_adaptive_pass_x");

				path.setTarget("tex");
				path.bindTarget(targetb, "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				path.drawShader("shader_datas/blur_adaptive_pass/blur_adaptive_pass_y3_blend");
			}
		}
		#end

		#if ((rp_motionblur == "Camera") || (rp_motionblur == "Object"))
		{
			if (armory.data.Config.raw.rp_motionblur != false) {
				path.setTarget("buf");
				path.bindTarget("tex", "tex");
				path.bindTarget("gbuffer0", "gbuffer0");
				#if (rp_motionblur == "Camera")
				{
					path.bindTarget("_main", "gbufferD");
					path.drawShader("shader_datas/motion_blur_pass/motion_blur_pass");
				}
				#else
				{
					path.bindTarget("gbuffer2", "sveloc");
					path.drawShader("shader_datas/motion_blur_veloc_pass/motion_blur_veloc_pass");
				}
				#end
				path.setTarget("tex");
				path.bindTarget("buf", "tex");
				path.drawShader("shader_datas/copy_pass/copy_pass");
			}
		}
		#end

		// We are just about to enter compositing, add more custom passes here
		// #if rp_custom_pass
		// {
		// }
		// #end

		// Begin compositor
		#if rp_autoexposure
		{
			path.generateMipmaps("tex");
		}
		#end

		#if ((rp_supersampling == 4) || (rp_rendercapture))
		var framebuffer = "buf";
		#else
		var framebuffer = "";
		#end

		#if ((rp_antialiasing == "Off") || (rp_antialiasing == "FXAA") || (!rp_render_to_texture))
		{
			RenderPathCreator.finalTarget = path.currentTarget;
			path.setTarget(framebuffer);
		}
		#else
		{
			RenderPathCreator.finalTarget = path.currentTarget;
			path.setTarget("buf");
		}
		#end
		
		path.bindTarget("tex", "tex");
		#if rp_compositordepth
		{
			path.bindTarget("_main", "gbufferD");
		}
		#end

		#if rp_compositornodes
		{
			if (!path.isProbe) path.drawShader("shader_datas/compositor_pass/compositor_pass");
			else path.drawShader("shader_datas/copy_pass/copy_pass");
		}
		#else
		{
			path.drawShader("shader_datas/copy_pass/copy_pass");
		}
		#end
		// End compositor

		#if rp_overlays
		{
			path.clearTarget(null, 1.0);
			path.drawMeshes("overlay");
		}
		#end

		#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
		{
			path.setTarget("bufa");
			path.clearTarget(0x00000000);
			path.bindTarget("buf", "colorTex");
			path.drawShader("shader_datas/smaa_edge_detect/smaa_edge_detect");

			path.setTarget("bufb");
			path.clearTarget(0x00000000);
			path.bindTarget("bufa", "edgesTex");
			path.drawShader("shader_datas/smaa_blend_weight/smaa_blend_weight");

			#if (rp_antialiasing == "TAA")
			path.isProbe ? path.setTarget(framebuffer) : path.setTarget("bufa");
			#else
			path.setTarget(framebuffer);
			#end
			path.bindTarget("buf", "colorTex");
			path.bindTarget("bufb", "blendTex");
			#if (rp_antialiasing == "TAA")
			{
				path.bindTarget("gbuffer2", "sveloc");
			}
			#end
			path.drawShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");

			#if (rp_antialiasing == "TAA")
			{
				if (!path.isProbe) { // No last frame for probe

					// Paint
					var isLast = arm.UITrait.inst.ddirty == 1 || arm.UITrait.inst.rdirty == 1;
					path.setTarget(isLast ? "bufb" : framebuffer);
					path.bindTarget("bufa", "tex");
					path.bindTarget("taa", "tex2");
					path.bindTarget("gbuffer2", "sveloc");
					path.drawShader("shader_datas/taa_pass/taa_pass");
					if (isLast) {
						path.setTarget(framebuffer);
						path.bindTarget("bufb", "tex");
						path.drawShader("shader_datas/copy_pass/copy_pass");
					}
					else {
						path.setTarget("taa");
						path.bindTarget("bufa", "tex");
						path.drawShader("shader_datas/copy_pass/copy_pass");
					}
					//
					// path.setTarget(framebuffer);
					// path.bindTarget("bufa", "tex");
					// path.bindTarget("taa", "tex2");
					// path.bindTarget("gbuffer2", "sveloc");
					// path.drawShader("shader_datas/taa_pass/taa_pass");
					// path.setTarget("taa");
					// path.bindTarget("bufa", "tex");
					// path.drawShader("shader_datas/copy_pass/copy_pass");
					//
				}
			}
			#end
		}
		#end

		#if (rp_supersampling == 4)
		{
			var finalTarget = "";
			path.setTarget(finalTarget);
			path.bindTarget(framebuffer, "tex");
			path.drawShader("shader_datas/supersample_resolve/supersample_resolve");
		}
		#end

		// paint
		arm.UITrait.inst.ddirty--;
		arm.UITrait.inst.pdirty--;
		arm.UITrait.inst.rdirty--;
		//
	}

	@:access(iron.RenderPath)
	public static function commandsPreview() {

		#if rp_gbuffer2
		{
			path.setTarget("mgbuffer2");
			path.clearTarget(0xff000000);
			path.setTarget("mgbuffer0", ["mgbuffer1", "mgbuffer2"]);
		}
		#else
		{
			path.setTarget("mgbuffer0", ["mgbuffer1"]);
		}
		#end

		#if (rp_background == "Clear")
		{
			path.clearTarget(-1, 1.0);
		}
		#else
		{
			path.clearTarget(null, 1.0);
		}
		#end

		RenderPathCreator.drawMeshes();

		// Light
		path.setTarget("mtex");
		path.bindTarget("_mmain", "gbufferD");
		path.bindTarget("mgbuffer0", "gbuffer0");
		path.bindTarget("mgbuffer1", "gbuffer1");
		#if (rp_ssgi != "Off")
		{
			path.bindTarget("empty_white", "ssaotex");
		}
		#end
		path.drawShader("shader_datas/deferred_light/deferred_light");

		#if (rp_background == "World")
		{
			path.drawSkydome("shader_datas/world_pass/world_pass");
		}
		#end
		
		var framebuffer = "texpreview";

		#if arm_editor
		var selectedMat = arm.UITrait.inst.htab.position == 0 ? arm.UITrait.inst.selectedMaterial2 : arm.UITrait.inst.selectedMaterial;
		#else
		var selectedMat = arm.UITrait.inst.selectedMaterial;
		#end
		iron.RenderPath.active.renderTargets.get("texpreview").image = selectedMat.image;

		#if ((rp_antialiasing == "Off") || (rp_antialiasing == "FXAA") || (!rp_render_to_texture))
		{
			path.setTarget(framebuffer);
		}
		#else
		{
			path.setTarget("mbuf");
		}
		#end
		
		path.bindTarget("mtex", "tex");
		#if rp_compositordepth
		{
			path.bindTarget("_mmain", "gbufferD");
		}
		#end

		#if rp_compositornodes
		{
			path.drawShader("shader_datas/compositor_pass/compositor_pass");
		}
		#else
		{
			path.drawShader("shader_datas/copy_pass/copy_pass");
		}
		#end

		#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
		{
			path.setTarget("mbufa");
			path.clearTarget(0x00000000);
			path.bindTarget("mbuf", "colorTex");
			path.drawShader("shader_datas/smaa_edge_detect/smaa_edge_detect");

			path.setTarget("mbufb");
			path.clearTarget(0x00000000);
			path.bindTarget("mbufa", "edgesTex");
			path.drawShader("shader_datas/smaa_blend_weight/smaa_blend_weight");

			path.setTarget(framebuffer);
			path.clearTarget(0x00000000, 0.0);

			path.bindTarget("mbuf", "colorTex");
			path.bindTarget("mbufb", "blendTex");
			#if (rp_antialiasing == "TAA")
			{
				path.bindTarget("mgbuffer2", "sveloc");
			}
			#end
			path.drawShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");
		}
		#end
	}

	@:access(iron.RenderPath)
	public static function commandsSticker() {
		
		#if rp_gbuffer2
		{
			path.setTarget("gbuffer2");
			path.clearTarget(0xff000000);
			path.setTarget("gbuffer0", ["gbuffer1", "gbuffer2"]);
		}
		#else
		{
			path.setTarget("gbuffer0", ["gbuffer1"]);
		}
		#end

		#if (rp_background == "Clear")
		{
			path.clearTarget(-1, 1.0);
		}
		#else
		{
			path.clearTarget(null, 1.0);
		}
		#end

		RenderPathCreator.drawMeshes();

		// Light
		path.setTarget("tex");
		path.bindTarget("_main", "gbufferD");
		path.bindTarget("gbuffer0", "gbuffer0");
		path.bindTarget("gbuffer1", "gbuffer1");
		#if (rp_ssgi != "Off")
		{
			path.bindTarget("empty_white", "ssaotex");
		}
		#end
		path.drawShader("shader_datas/deferred_light/deferred_light");

		#if (rp_background == "World")
		{
			path.drawSkydome("shader_datas/world_pass/world_pass");
		}
		#end
		
		var framebuffer = "texpreview";

		iron.RenderPath.active.renderTargets.get("texpreview").image = arm.UITrait.inst.stickerImage;

		#if ((rp_antialiasing == "Off") || (rp_antialiasing == "FXAA") || (!rp_render_to_texture))
		{
			path.setTarget(framebuffer);
		}
		#else
		{
			path.setTarget("buf");
		}
		#end
		
		path.bindTarget("tex", "tex");
		#if rp_compositordepth
		{
			path.bindTarget("_main", "gbufferD");
		}
		#end

		#if rp_compositornodes
		{
			path.drawShader("shader_datas/compositor_pass/compositor_pass");
		}
		#else
		{
			path.drawShader("shader_datas/copy_pass/copy_pass");
		}
		#end

		#if ((rp_antialiasing == "SMAA") || (rp_antialiasing == "TAA"))
		{
			path.setTarget("bufa");
			path.clearTarget(0x00000000);
			path.bindTarget("buf", "colorTex");
			path.drawShader("shader_datas/smaa_edge_detect/smaa_edge_detect");

			path.setTarget("bufb");
			path.clearTarget(0x00000000);
			path.bindTarget("bufa", "edgesTex");
			path.drawShader("shader_datas/smaa_blend_weight/smaa_blend_weight");

			path.setTarget(framebuffer);
			path.clearTarget(0x00000000, 0.0);

			path.bindTarget("buf", "colorTex");
			path.bindTarget("bufb", "blendTex");
			#if (rp_antialiasing == "TAA")
			{
				path.bindTarget("gbuffer2", "sveloc");
			}
			#end
			path.drawShader("shader_datas/smaa_neighborhood_blend/smaa_neighborhood_blend");
		}
		#end
	}

	#end
}
