import Array "mo:base/Array";
import D "mo:base/Debug";

import Int "mo:base/Int";

import Principal "mo:base/Principal";

import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat "mo:base/Nat";


import Vec "mo:vector";

import ICRC104 "mo:icrc104-mo";
import ICRC104Service "mo:icrc104-mo/service";
import ICRC10 "mo:icrc10-mo";
import ICRC75Service "mo:icrc75-mo/service";
import ICRC75 "mo:icrc75-mo";

import Timer "mo:base/Timer";

import CertTree "mo:ic-certification/CertTree";
import RoleRotator ".";


shared ({ caller = _owner }) actor class Token  (
    init_args : ?{
      icrc104: ICRC104.InitArgs;
      icrc75: ICRC75.InitArgs;
    }
) = this{

    let icrc104_args : ICRC104.InitArgs = do?{init_args!.icrc104!};
    let icrc75_args : ICRC75.InitArgs = do?{init_args!.icrc75!};

    let ONE_DAY = 86_400_000_000_000; //NanoSeconds

    stable let icrc104_migration_state = ICRC104.init(ICRC104.initialState(), #v0_1_0(#id), icrc104_args, _owner);

    let #v0_1_0(#data(icrc104_state_current)) = icrc104_migration_state;

    private var _icrc104 : ?ICRC104.ICRC104 = null;

    private func get_icrc104_environment() : ICRC104.Environment {
    {
      add_ledger_transaction = null;
      advanced = null;
      tt = null;
    };
  };

  func icrc104() : ICRC104.ICRC104 {
    switch(_icrc104){
      case(null){
        let initclass : ICRC104.ICRC104 = ICRC104.ICRC104(?icrc104_migration_state, Principal.fromActor(this), get_icrc104_environment());
        _icrc104 := ?initclass;
        initclass;
      };
      case(?val) val;
    };
  };

  stable var icrc10 = ICRC10.initCollection();

  //call this function with:
  // dfx canister call king auto_init
  /* {
    icrc75Canister = "nn7ao-eiaaa-aaaap-akjoq-cai";
    target_list = "org.icdevs.lists.king_of_the_hill";                     // The list to apply rules on
    members: [];                // Optional identity triggering the rule application
    rule_namespace: "org.icdevs.role_rotator.king";     // Namespace identifying the rule set to apply
    metadata: null;                     // Optional metadata associated with the operation
  }; */
  public shared(msg) func icrc104_apply_rules(request: ICRC104Service.ApplyRuleRequest) : async ICRC104Service.ApplyRuleResult {
    D.print("in icrc104_apply_rules");
    await* icrc104().apply_rule_handler(msg.caller, request);
  };

  public type DataItemMap = ICRC75Service.DataItemMap;
  public type ManageRequest = ICRC75Service.ManageRequest;
  public type ManageResult = ICRC75Service.ManageResult;
  public type ManageListMembershipRequest = ICRC75Service.ManageListMembershipRequest;
  public type ManageListMembershipRequestItem = ICRC75Service.ManageListMembershipRequestItem;
  public type ManageListMembershipAction = ICRC75Service.ManageListMembershipAction;
  public type ManageListPropertyRequest = ICRC75Service.ManageListPropertyRequest;
  public type ManageListMembershipResponse = ICRC75Service.ManageListMembershipResponse;
  public type ManageListPropertyRequestItem = ICRC75Service.ManageListPropertyRequestItem;
  public type ManageListPropertyResponse = ICRC75Service.ManageListPropertyResponse;
  public type AuthorizedRequestItem = ICRC75Service.AuthorizedRequestItem;
  public type PermissionList = ICRC75Service.PermissionList;
  public type PermissionListItem = ICRC75Service.PermissionListItem;
  public type ListRecord = ICRC75Service.ListRecord;
  public type List = ICRC75.List;
  public type ListItem = ICRC75.ListItem;
  public type Permission = ICRC75.Permission;
  public type Identity = ICRC75.Identity;
  public type ManageResponse = ICRC75Service.ManageResponse;

  public query(msg) func getLedger() : async [ICRC75.Value] {
    return Vec.toArray(fakeLedger);
  };

  stable let fakeLedger = Vec.new<ICRC75.Value>(); //maintains insertion order

  public shared(msg) func validateApplyRule(request: ICRC104Service.ApplyRuleRequest) : async ICRC104.SNSValidationResponse {
    await* icrc104().validate_rule_handler(msg.caller, request);
  };
  let ONE_MINUTE = 60_000_000_000; //NanoSeconds

  stable var lastCall = Time.now() - (ONE_MINUTE * 3);

  

  ignore Timer.setTimer<system>(#nanoseconds(0), func() : async(){
    let thisActor : actor{
      auto_init : () -> async ();
    } = actor(Principal.toText(Principal.fromActor(this)));
    await thisActor.auto_init();
  });

  private func qualify(foundMembers: [ListItem], event: ICRC104.HandleRuleEvent, bAwaited: Bool) : async* RoleRotator.QualifyFunctionResponse {

     if(Time.now() < lastCall + (ONE_MINUTE * 3)){
        return #err(#trappable(#apply(#Err(#ExecutionFailed("You must wait 3 minutes between calls")))));
     };

     return #trappable(foundMembers); 
  };

  var _role_rotator : ?RoleRotator.RoleRotator = null;
 
  public shared(msg) func auto_init() : async() {
    D.print("in auto_init");

    
    for(thisStandard in icrc104().supported_standards().vals()){
      ICRC10.register(icrc10, thisStandard);
    };

    icrc104().addAdmin(Principal.fromText("2vxsx-fae"));

    _role_rotator := ?RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = null;
        icrc104 = icrc104();
        validator = null;
        qualifyFunction = ?qualify;
        ruleNamespace = "org.icdevs.role_rotator.king";
        eligibleList = "org.icdevs.lists.cool_kids";
    });

  };
};



