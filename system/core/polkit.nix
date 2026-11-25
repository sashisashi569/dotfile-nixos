{ pkgs, ... }:

{
  security.polkit.enable = true;
  security.polkit.enablePkexecWrapper = true;

  # Allow wheel group members to run any command via pkexec, requiring self-password each time
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.policykit.exec" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.AUTH_SELF;
      }
    });
  '';
}
