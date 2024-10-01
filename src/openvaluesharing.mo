module {
  public let openvaluesharing = {
    platform = "icp";
    asset = "cycles";
    payment_mechanism = "icrc85_deposit_cycles_notify";
    custom = [
      {
        key = "namespace";
        value = #text("org.icdevs.libraries.af-role-rotator");
      },
      {
        key = "principal";
        value = #text("q26le-iqaaa-aaaam-actsa-cai");
      }
    ]
  };
};