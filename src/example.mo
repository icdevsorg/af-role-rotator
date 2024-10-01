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

    type pBobStats = { 
        totalSupply : Nat;
        holders : Nat;
        miners : Nat;
        totalBobWithdrawn: Nat;
        totalBobDist: Nat;
        totalCyclesFunded : Nat;
        lastCyclesFunded : Int;
        lastDistribute : Int;
        solvedChallenges: Nat64;
        hashesComputed: Nat;
        bDist: Bool;
    };

    let pBob : actor {
      stats: () -> async pBobStats;
    } = actor("oqvo3-qqaaa-aaaas-aibca-cai");

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
  stable var last_market_maker_replacement : Nat = 0;

  stable let icrc75_migration_state = ICRC75.migrate(ICRC75.initialState(), #v0_1_1(#id), icrc75_args, _owner);

    let #v0_1_1(#data(icrc75_state_current)) = icrc75_migration_state;

    private var _icrc75 : ?ICRC75.ICRC75 = null;


    private func get_icrc75_state() : ICRC75.CurrentState {
      return icrc75_state_current;
    };

    stable let cert_store : CertTree.Store = CertTree.newStore();
    let ct = CertTree.Ops(cert_store);

    private func getCertStore() : CertTree.Store {
      
      return cert_store;
    };

    stable let fakeLedger = Vec.new<ICRC75.Value>(); //maintains insertion order

    private func fakeledgerAddRecord<system>(trx: ICRC75.Value, trxTop: ?ICRC75.Value) : Nat {

      let finalMap = switch(trxTop){
        case(?#Map(top)) {
          let combined = Array.append<(Text, ICRC75.Value)>(top, [("tx",trx)]);
          #Map(combined);
        };
        case(_) {
          #Map([("op",trx)]);
        };
      };
      Vec.add(fakeLedger, finalMap);
      Vec.size(fakeLedger) - 1;
    };

    private func get_icrc75_environment() : ICRC75.Environment {
    {
      advanced = null;
      tt = null; // for recovery and safety you likely want to provide a timer tool instance here
      updated_certification = null; //called when a certification has been made
      get_certificate_store = ?getCertStore; //needed to pass certificate store to the class
      addRecord = ?fakeledgerAddRecord;
      icrc10_register_supported_standards = func(a : ICRC10.Entry): Bool {
        ICRC10.register(icrc10, a);
        true;
      };
    };
  };

  func icrc75() : ICRC75.ICRC75 {
    switch(_icrc75){
      case(null){
        let initclass : ICRC75.ICRC75 = ICRC75.ICRC75(?icrc75_migration_state, Principal.fromActor(this), get_icrc75_environment());
        _icrc75 := ?initclass;
        
        initclass;
        
      };
      case(?val) val;
    };
  };

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


  public query(msg) func icrc75_metadata() : async DataItemMap {
    return icrc75().metadata();
  };

  public shared(msg) func icrc75_manage(request: ManageRequest) : async ManageResponse {
      return icrc75().updateProperties<system>(msg.caller, request);
    };

  public shared(msg) func icrc75_manage_list_membership(request: ManageListMembershipRequest) : async ManageListMembershipResponse {
    return await* icrc75().manage_list_membership(msg.caller, request, null);
  };

  public shared(msg) func icrc75_manage_list_properties(request: ManageListPropertyRequest) : async ManageListPropertyResponse {
    return await* icrc75().manage_list_properties(msg.caller, request, null);
  };

  public query(msg) func icrc75_get_lists(name: ?Text, bMetadata: Bool, cursor: ?List, limit: ?Nat) : async [ListRecord] {
    return icrc75().get_lists(msg.caller, name, bMetadata, cursor, limit);
  };

  public query(msg) func icrc75_get_list_members_admin(list: List, cursor: ?ListItem, limit: ?Nat) : async [ListItem] {
    return icrc75().get_list_members_admin(msg.caller, list, cursor, limit);
  };

  public query(msg) func icrc75_get_list_permissions_admin(list: List, filter: ?Permission, prev: ?PermissionListItem, take: ?Nat) : async PermissionList {
    return icrc75().get_list_permission_admin(msg.caller, list, filter, prev, take);
  };

  public query(msg) func icrc75_get_list_lists(list: List, cursor: ?List, limit: ?Nat) : async [List] {
    return icrc75().get_list_lists(msg.caller, list, cursor, limit);
  };

  public query(msg) func icrc75_member_of(listItem: ListItem, list: ?List, limit: ?Nat) : async [List] {
    return icrc75().member_of(msg.caller, listItem, list, limit);
  };

  public query(msg) func icrc75_is_member(requestItems: [AuthorizedRequestItem]) : async [Bool] {
    return icrc75().is_member(msg.caller, requestItems);
  };

  public shared(msg) func icrc75_request_token(listItem: ListItem, list: List, ttl: ?Nat) : async ICRC75.IdentityRequestResult {
    return icrc75().request_token<system>(msg.caller,listItem, list, ttl);
  };

  public query(msg) func icrc75_retrieve_token(token: ICRC75.IdentityToken) : async ICRC75.IdentityCertificate {
    return icrc75().retrieve_token(msg.caller, token);
  };

  

  public query(msg) func getLedger() : async [ICRC75.Value] {
    return Vec.toArray(fakeLedger);
  };

  public shared(msg) func validateApplyRule(request: ICRC104Service.ApplyRuleRequest) : async ICRC104.SNSValidationResponse {
    await* icrc104().validate_rule_handler(msg.caller, request);
  };


  private func validate_custom(event: ICRC104.HandleRuleEvent) : async* ICRC104.SNSValidationResponse {
    return #Ok("Valid Submission");
  };


  private func qualify_all_member(foundMembers: [ListItem], event: ICRC104.HandleRuleEvent, bAwaited: Bool) : async* RoleRotator.QualifyFunctionResponse {
    return #trappable(foundMembers);
  };

  private func qualify_one_member(foundMembers: [ListItem], event: ICRC104.HandleRuleEvent, bAwaited: Bool) : async* RoleRotator.QualifyFunctionResponse {
    return #trappable([foundMembers[0]]);
  };

  private func qualify_no_member(foundMembers: [ListItem], event: ICRC104.HandleRuleEvent, bAwaited: Bool) : async* RoleRotator.QualifyFunctionResponse {
    return #trappable([]);
  };

  private func qualify_not_qualifying(foundMembers: [ListItem], event: ICRC104.HandleRuleEvent, bAwaited: Bool) : async* RoleRotator.QualifyFunctionResponse {
     return #err(#trappable(#apply(#Err(#ExecutionFailed("not qualifying"))))); 
  };


  private func qualify_market_maker_replacement(foundMembers: [ListItem], event: ICRC104.HandleRuleEvent, bAwaited: Bool) : async* RoleRotator.QualifyFunctionResponse {
    let lastDist = await pBob.stats();

    if(Int.abs(lastDist.lastDistribute) + (ONE_DAY * 2) < Int.abs(Time.now())){
      //qualified for replacement
      if(last_market_maker_replacement + (ONE_DAY * 2) < Int.abs(Time.now())){
        //qualified for replacement
      } else {
        return #err(#awaited(#apply(#Ok(#LocalTrx{
          metadata = [(
            "result", #Text("nothing done - found recent reassignment")
          )];
          transactions = [];
        })))); 
      }
    } else {
      return #err(#awaited(#apply(#Ok(#LocalTrx{
        metadata = [
          ("result", #Text("nothing done - found recent distribution"))
        ];
        transactions = [];
      }))));
    };

    return #awaited(foundMembers);
  };

  ignore Timer.setTimer<system>(#nanoseconds(0), func() : async(){
    let thisActor : actor{
      auto_init : () -> async ();
    } = actor(Principal.toText(Principal.fromActor(this)));
    await thisActor.auto_init();
  });

  var _role_rotator : ?RoleRotator.RoleRotator = null;
  var _role_rotator_all : ?RoleRotator.RoleRotator = null;
  var _role_rotator_one : ?RoleRotator.RoleRotator = null;
  var _role_rotator_none : ?RoleRotator.RoleRotator = null;
  var _role_rotator_nonQualify : ?RoleRotator.RoleRotator = null;

  public shared(msg) func auto_init() : async() {
    D.print("in auto_init");
    icrc75().init<system>();
    
    for(thisStandard in icrc104().supported_standards().vals()){
      ICRC10.register(icrc10, thisStandard);
    };

    _role_rotator := ?RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = ?icrc75();
        icrc104 = icrc104();
        validator = null;
        qualifyFunction = ?qualify_market_maker_replacement;
        ruleNamespace = "org.icdevs.pbob.role_replacer.market_maker";
        eligibleList = "org.icdevs.pbob.role_replacer.market_maker_eligible";

    });

    _role_rotator_all := ?RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = ?icrc75();
        validator = null;
        icrc104 = icrc104();
        qualifyFunction = ?qualify_all_member;
        ruleNamespace = "replaceAll";
        eligibleList = "sourceList";

    });

    _role_rotator_one := ?RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = ?icrc75();
        icrc104 = icrc104();
        validator = null;
        qualifyFunction = ?qualify_one_member;
        ruleNamespace = "replaceOne";
        eligibleList = "sourceList";

    });

    _role_rotator_none := ?RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = ?icrc75();
        icrc104 = icrc104();
        validator = null;
        qualifyFunction = ?qualify_no_member;
        ruleNamespace = "replaceNone";
        eligibleList = "sourceList";

    });

    _role_rotator_nonQualify := ?RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = ?icrc75();
        icrc104 = icrc104();
        validator = ?validate_custom;
        qualifyFunction = ?qualify_not_qualifying;
        ruleNamespace = "replaceNonQualify";
        eligibleList = "sourceList";

    });
  };
};



