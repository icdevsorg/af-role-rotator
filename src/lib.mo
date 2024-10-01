import ICRC104 "mo:icrc104-mo";
import ICRC104Service "mo:icrc104-mo/service";
import ICRC10 "mo:icrc10-mo";
import ICRC75Service "mo:icrc75-mo/service";
import ICRC75 "mo:icrc75-mo";
import Star "mo:star/star";
import Set "mo:map/Set";
import Map "mo:map/Map";
import TT "mo:timer-tool";
import ovsfixed "mo:ovs-fixed";

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import D "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

import PseudoRandom "mo:xtended-random/PseudoRandomX";

module{

  let debug_channel = {
    announce = true;
  };

  public type QualifyFunctionResponse = Star.Star<[ICRC75.ListItem], ICRC104.RuleHandlerResponse>;

  public type QualifyFunction = ([ICRC75.ListItem], ICRC104.HandleRuleEvent, Bool) -> async*  (QualifyFunctionResponse);

  public type ICRC85Options = {
    kill_switch: ?Bool;
    handler: ?(([(Text, ICRC75.ICRC16Map)]) -> ());
    period: ?Nat;
    tree: ?[Text];
    asset: ?Text;
    platform: ?Text;
    collector: ?Principal;
  };

  public type InitArgs = {
    icrc75: ?ICRC75.ICRC75;
    icrc104: ICRC104.ICRC104;
    ruleNamespace: Text;
    eligibleList: Text;
    canister: Principal;
    qualifyFunction: ?QualifyFunction;
    validator: ?ICRC104.RuleValidator;
  };

  public class RoleRotator(init: InitArgs) {

    private func getListFromRemote(listName : Text, icrc75Canister: Principal, bAwaited: Bool) : async* Star.Star<[ICRC75.ListItem], ICRC104.RuleHandlerResponse>{
      let icrc75Service : ICRC75Service.Service = actor(Principal.toText(icrc75Canister));
      var foundEnd = false;
      var count = 0;

      let buff = Buffer.Buffer<ICRC75.ListItem>(1);
      var prev: ?ICRC75.ListItem = null;

      while(foundEnd == false and count < 50){
        let items = try{
          await icrc75Service.icrc75_get_list_members_admin(listName, prev, null)} catch (err) {
            return if(bAwaited){
                #err(#awaited(#apply(#Err(#ExecutionFailed("market maker list not found " # debug_show(count) # " " # Error.message(err))))));
              } else {
                #err(#trappable(#apply(#Err(#ExecutionFailed("market maker list not found " # debug_show(count) # " " # Error.message(err))))));
              };
          };

        if(items.size() == 0){
          foundEnd := true;
        } else {
          count += 1;

          ignore Array.map<ICRC75.ListItem, ()>(items, func(x: ICRC75.ListItem) {
            buff.add(x)
          });
        
          prev := ?items[items.size() - 1];
        };
      };
      return #awaited(Buffer.toArray(buff));
    };

    public func getList(listName : Text, icrc75Canister: Principal, bAwaited: Bool) : async* Star.Star<[ICRC75.ListItem], ICRC104.RuleHandlerResponse> { 

      switch(init.icrc75, init.canister == icrc75Canister){
        case(?icrc75, true){
          let ?items = ICRC75.BTree.get(icrc75.get_state().namespaceStore, Text.compare, listName) else {
            return if(bAwaited){
              #err(#awaited(#apply(#Err(#ExecutionFailed("market maker list not found")))));
            } else {
              #err(#trappable(#apply(#Err(#ExecutionFailed("market maker list not found")))));
            };
          };
          return if(bAwaited){
            #awaited(Set.toArray(items.members));
          } else {
            #trappable(Set.toArray(items.members));
          }
        };
        case(null, true) return await* getListFromRemote(listName, icrc75Canister, bAwaited);
        case(_, false) return await* getListFromRemote(listName, icrc75Canister, bAwaited);
      };
    };

    public func defaultValidationMessage(request: ICRC104.HandleRuleEvent) : Text {
      return "Apply the rule " # request.rule_namespace # " on " # request.target_list # " with the call object " # debug_show(request);
    };

    public func run_validator<system>(request: ICRC104.HandleRuleEvent) : async* ICRC104.SNSValidationResponse {


      if(not Set.has(init.icrc104.get_state().admins, Set.phash, request.caller)){
        return #Err("caller not authorized");
      };

      switch(init.validator){
        case(?validator){
          switch(await* validator(request)){
            case(#Err(response)) return #Err(response);
            case(#Ok(response)) return #Ok(response);
          };
        };
        case(null) {
          return #Ok(defaultValidationMessage(request));
        };
      };
    };

    public func replace_role<system>(request: ICRC104.HandleRuleEvent, bSimulate : Bool) : async* Star.Star<ICRC104.RuleHandlerResponse,()> {

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role" # debug_show(request));

      if(request.rule_namespace != init.ruleNamespace){
        return #trappable(#apply(#Err(#ExecutionFailed("rule namespace mismatch"))));
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role" # debug_show(Set.toArray(init.icrc104.get_state().admins)));
      if(not Set.has(init.icrc104.get_state().admins, Set.phash, request.caller)){
        return #trappable(#apply(#Err(#ExecutionFailed("caller not authorized"))));
      };


      if(bSimulate){
        return #trappable(#apply(#Err(#ExecutionFailed("simulation not supported"))));
      };

      var bAwaited = false;

      //qualify the request

     debug if(debug_channel.announce) D.print("RoleRotator: replace_role about to get list" # debug_show(request));

      //Get the current source list
      let sourceItems = switch(await* getList(request.target_list, request.icrc75Canister, false)){
        case(#awaited(sourceItems)){
          bAwaited := true;
          sourceItems;
        };
        case(#trappable(sourceItems)) sourceItems;
        case(#err(#awaited(err))) return #awaited(err);
        case(#err(#trappable(err))) return #trappable(err);
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role sourceItems " # debug_show(sourceItems));

      let sourceSet = Set.fromIter<ICRC75.ListItem>(sourceItems.vals(), ICRC75.listItemHash);

      let exclude = switch(init.qualifyFunction){
        case(null) sourceItems;
        case(?qualify){
          switch(await* qualify(sourceItems, request, bAwaited)){
            case(#awaited(exclude)){
              bAwaited := true;
              exclude;
            };
            case(#trappable(exclude)) exclude;
            case(#err(#trappable(err))) return if(bAwaited){
             #awaited(err);
            } else {
              #trappable(err);
            };
            case(#err(#awaited(err))) return #awaited(err);
          };
        };
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role exclude " # debug_show(exclude));

      let eligible = switch(await* getList(init.eligibleList, request.icrc75Canister, false)){
        case(#awaited(eligible)){
          bAwaited := true;
          eligible;
        };
        case(#trappable(eligible)) eligible;
        case(#err(#awaited(err))) return #awaited(err);
        case(#err(#trappable(err))) return if(bAwaited){
            #awaited(err);
          }else {
            #trappable(err)
          };
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role eligible " # debug_show(eligible));

      let candidates = Array.filter<ICRC75.ListItem>(eligible, func (x : ICRC75.ListItem) : Bool{
        if(Set.has(sourceSet, ICRC75.listItemHash, x)){
          false;
        } else {
          true;
        };
      });

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role candidates " # debug_show(candidates));

      let initialSize = exclude.size();
      let candidateCount = candidates.size();

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role initialSize " # debug_show(initialSize) # " candidateCount " # debug_show(candidateCount));

      if(initialSize == 0){
        return if(bAwaited){
            #awaited(#apply(#Err(#ExecutionFailed("no qualifiying members for replacement"))))}
        else {
            #trappable(#apply(#Err(#ExecutionFailed("no qualifiying members for replacement"))));
        };
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role initialSize " # debug_show(initialSize) # " candidateCount " # debug_show(candidateCount));

      if(candidateCount == 0){
        return if(bAwaited){
          #awaited(#apply(#Err(#ExecutionFailed("no candiates"))))
        } else {
          #trappable(#apply(#Err(#ExecutionFailed("no candiates"))));
        };
      };

      let replacementsCount = if(candidateCount >= initialSize){
        initialSize;
      } else {
        candidateCount;
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role replacementsCount " # debug_show(replacementsCount));

      let seed = Nat.rem(Int.abs(Time.now()), 4_294_967_296);

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role seed " # debug_show(seed));

      let rnd = PseudoRandom.fromSeed(Nat32.fromNat(Int.abs(seed)), #xorshift32);

      let swaps = Buffer.Buffer<(Nat, Nat)>(1);
      let removedSet = Set.new<Nat>();
      let addedSet = Set.new<Nat>();

      var tries = 0;

      label proc while(swaps.size() < replacementsCount and tries < replacementsCount + 100){
        tries += 1;
        let replacedIndex = rnd.nextNat(0, initialSize);
        let replacementIndex = rnd.nextNat(0, candidateCount);

        debug if(debug_channel.announce) D.print("RoleRotator: replace_role replacedIndex " # debug_show(replacedIndex) # " replacementIndex " # debug_show(replacementIndex));

        

        if(Set.has(removedSet, Set.nhash, replacedIndex) or Set.has(addedSet, Set.nhash,  replacementIndex)){
          debug if(debug_channel.announce) D.print("RoleRotator: replace_role already swapped " # debug_show(replacedIndex) # " " # debug_show(replacementIndex));
          continue proc;
        };

        ignore Set.put(removedSet, Set.nhash, replacedIndex);
        ignore Set.put(addedSet, Set.nhash, replacementIndex);

        swaps.add((replacedIndex, replacementIndex));
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role swaps " # debug_show(Buffer.toArray(swaps)));

      let commands = Buffer.Buffer<ICRC75Service.ManageListMembershipRequestItem>(1);

      for(thisSwap in swaps.vals()){
        commands.add({
          list = request.target_list;
          memo = null;
          from_subaccount = null;
          created_at_time = ?Int.abs(Time.now());
          action = #Remove(exclude[thisSwap.0]);
        } : ICRC75Service.ManageListMembershipRequestItem);
        commands.add({
          list = request.target_list;
          memo = null;
          from_subaccount = null;
          created_at_time = ?Int.abs(Time.now());
          action = #Add(candidates[thisSwap.1]);
        } : ICRC75Service.ManageListMembershipRequestItem);
      };

      let allItems : ICRC75Service.ManageListMembershipRequest = Buffer.toArray<ICRC75Service.ManageListMembershipRequestItem>(commands);

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role allItems " # debug_show(allItems));

      let result = try{
        switch(init.icrc75){
          case(?icrc75){
            await* icrc75.manage_list_membership(init.canister, allItems, null);
          };
          case(null){
            let icrc75Service : ICRC75Service.Service = actor(Principal.toText(request.icrc75Canister));
            bAwaited := true;
            await icrc75Service.icrc75_manage_list_membership(allItems);
          };
        };
      } catch (err) {
        debug if(debug_channel.announce) D.print("RoleRotator: replace_role err " # Error.message(err));
        return if(bAwaited){
          #awaited(#apply(#Err(#ExecutionFailed("Failed submiting batch" # Error.message(err)))));
        } else {
          #trappable(#apply(#Err(#ExecutionFailed("Failed submiting batch" # Error.message(err)))));
        };
      };

      debug if(debug_channel.announce) D.print("RoleRotator: replace_role result " # debug_show(result));

      let trx = Buffer.Buffer<Nat>(1);
      var metadata = "";

      var counter = 0;

      for(thisResult in result.vals()){
        switch(thisResult){
          case(?#Ok(trxId)) {
            //do nothing
            trx.add(trxId);
          };
          case(?#Err(err)) {
            metadata := metadata # "an err " # debug_show(counter) #  debug_show(err);
          };
          case(null){
            metadata := metadata # "an err " # debug_show(counter) # " unexpected null result";
          };
        };
        counter += 1;
      };

      return if(bAwaited){
        #awaited(#apply(#Ok(#LocalTrx({
        metadata = if(metadata.size() > 0){
            [("errors", #Text(metadata))];
          }else {
            []
          };
        transactions = Buffer.toArray(trx);
      }))))} else {
        #trappable(#apply(#Ok(#LocalTrx({
          metadata = if(metadata.size() > 0){
              [("errors", #Text(metadata))];
            }else {
              []
            };
          transactions = Buffer.toArray(trx);
        }))));
      };
    };

    ignore init.icrc104.add_rule_handler_listener(init.ruleNamespace, replace_role, ?run_validator);

    var icrc85_nextCycleActionId : ?Nat = null;
    var icrc85_lastActionReported : ?Nat = null;
    var icrc85_activeActions = 0;

    private func get_time() : Nat {
      Int.abs(Time.now());
    };

    private func scheduleCycleShare<system>() : async() {
      //check to see if it already exists
      debug if(debug_channel.announce) D.print("in schedule cycle share");
      switch(icrc85_nextCycleActionId){
        case(?val){
          switch(Map.get(tt<system>().getState().actionIdIndex, Map.nhash, val)){
            case(?time) {
              //already in the queue
              return;
            };
            case(null) {};
          };
        };
        case(null){};
      };

      let result = tt<system>().setActionSync<system>(get_time(), ({actionType = "icrc85:ovs:shareaction:af-role-rotator"; params = Blob.fromArray([]);}));
      icrc85_nextCycleActionId := ?result.id;
    };

    private func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error>{

      D.print("in handle timer async " # debug_show((id,action)));
      switch(action.actionType){
        case("icrc85:ovs:shareaction:af-role-rotator"){
          await* shareCycles<system>();
          #awaited(id);
        };
        case(_) #trappable(id);
      };
    };

    private func shareCycles<system>() : async*(){
      debug if(debug_channel.announce) D.print("in share cycles ");
      let lastReportId = switch(icrc85_lastActionReported){
        case(?val) val;
        case(null) 0;
      };

      debug if(debug_channel.announce) D.print("last report id icrc104" # debug_show(lastReportId));

      let actions = if(icrc85_activeActions > 0){
        icrc85_activeActions;
      } else {1;};

      debug if(debug_channel.announce) D.print("actions 104" # debug_show(actions));

      var cyclesToShare = 1_000_000_000_000; //1 XDR

      if(actions > 0){
        let additional = Nat.div(actions, 10000);
        debug if(debug_channel.announce) D.print("additional " # debug_show(additional));
        cyclesToShare := cyclesToShare + (additional * 1_000_000_000_000);
        if(cyclesToShare > 100_000_000_000_000) cyclesToShare := 100_000_000_000_000;
      };

      debug if(debug_channel.announce) D.print("cycles to share" # debug_show(cyclesToShare));

      try{
        await* ovsfixed.shareCycles<system>({
          environment = do?{init.icrc104.get_advancedSettings()!.icrc85};
          namespace = "org.icdevs.libraries.icrc104";
          actions = 1;
          schedule = func <system>(period: Nat) : async* (){
            let result = tt<system>().setActionSync<system>(get_time() + period, {actionType = "icrc85:ovs:shareaction:af-role-rotator"; params = Blob.fromArray([]);});
            icrc85_nextCycleActionId := ?result.id;
          };
          cycles = cyclesToShare;
        });
      } catch(e){
        debug if (debug_channel.announce) D.print("error sharing cycles" # Error.message(e));
      };
    };

    let OneDay =  86_400_000_000_000;
    var _haveTimer : ?Bool = null;

    var bSetTT = false;

    private func tt<system>() : TT.TimerTool {
      let foundClass = init.icrc104.get_tt<system>();

      if(bSetTT == false){
        foundClass.registerExecutionListenerAsync(?"icrc85:ovs:shareaction:af-role-rotator", handleIcrc85Action : TT.ExecutionAsyncHandler);
        debug if(debug_channel.announce) D.print("Timer tool set up");
        ignore Timer.setTimer<system>(#nanoseconds(OneDay), scheduleCycleShare);
        bSetTT := true;
      };
      foundClass;
    };
  };
};