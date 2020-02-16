# USDConverter

### A USDZ-to-OBJ converter powered by Model I/O

## Usage

1. Use Xcode to compile the project.
2. Move the resulting `usdconv` binary somewhere into your PATH or into the same directory as the USDZ files you want to convert.
3. Execute it from the terminal like this:

```
usdconv model1.usdz
```

You can also convert multiple files in one go by simply specifying more files:

```
usdconv model1.usdz model2.usdz model3.usdz
```

Each input file will yield five output files:

* model.obj
* model.mtl
* model_ModelIO.obj
* model_ModelIO.mtl
* model_duplicates.txt

`model.obj` and `model.mtl` are the files you want.

The `*_ModelIO` files are just there for reference and can safely be discarded. They are the unchanged output of Apple's Model I/O API, but might not be useful, as they might contain *dozens* of duplicate materials that USDConverter usually filters out.

In case you want to use the `*_ModelIO` files anyway, `model.duplicates.txt` is a list of duplicate materials, sorted by amount of occurrences.

## Using Blender?

Check out my alternate OBJ importer with support for the additional PBR MTL directives: [io_scene_obj_modelio](https://github.com/SamusAranX/io_scene_obj_modelio)