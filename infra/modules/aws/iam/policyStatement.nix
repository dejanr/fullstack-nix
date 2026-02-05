{ lib, ... }:

{
  options = {
    effect = lib.mkOption {
      type = lib.types.str;
      default = "Allow";
      description = "Policy effect";
    };

    actions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Policy actions";
    };

    resources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Policy resources";
    };

    conditions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      description = "Policy conditions";
    };
  };
}
