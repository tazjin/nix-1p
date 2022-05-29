# The canonical source location of nix-1p is //nix/nix-1p in the TVL
# depot: https://code.tvl.fyi/about/nix/nix-1p
#
# This file configures TVL CI to mirror the subtree to GitHub.
{ depot ? { }, pkgs ? import <nixpkgs> { }, ... }:

(pkgs.runCommandLocal "nix-1p.md" { } ''
  cp ${./README.md} $out
'').overrideAttrs (_: {
  meta.ci.extraSteps.github = depot.tools.releases.filteredGitPush {
    filter = ":/nix/nix-1p";
    remote = "git@github.com:tazjin/nix-1p.git";
    ref = "refs/heads/master";
  };
})
