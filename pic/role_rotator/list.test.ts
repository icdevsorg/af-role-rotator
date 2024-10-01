import { Principal } from "@dfinity/principal";
import type { Identity } from '@dfinity/agent';
import { Ed25519KeyIdentity } from '@dfinity/identity';
import { HttpAgent, compare, lookup_path, Certificate, Cbor, HashTree } from '@dfinity/agent';



import { IDL } from "@dfinity/candid";

import {
  PocketIc,
  createIdentity,
  FromPathSubnetStateConfig,
  SubnetStateType
} from "@hadronous/pic";

import type {
  Actor,
  CanisterFixture
} from "@hadronous/pic";



import {idlFactory as icrc75IDLFactory,
  init as icrc75Init } from "../../src/declarations/rolerotator/rolerotator.did.js";
import type {
  _SERVICE as ICRC75Service,
  ManageListMembershipRequest,
  ManageListPropertyRequest,
  ListItem,
  Account,
DataItem} from "../../src/declarations/rolerotator/rolerotator.did.js";
export const sub_WASM_PATH = ".dfx/local/canisters/rolerotator/rolerotator.wasm";

let replacer = (_key: any, value: any) => typeof value === "bigint" ? value.toString() + "n" : value;


let pic: PocketIc;

let icrc75_fixture: CanisterFixture<ICRC75Service>;

const admin = createIdentity("admin");
const alice = createIdentity("alice");
const bob = createIdentity("bob");
const charlie = createIdentity("charlie");
const dan = createIdentity("dan");
const edina = createIdentity("edina");
const frank = createIdentity("frank");
const serviceProvider = createIdentity("serviceProvider");
const OneDay = BigInt(86400000000000); // 24 hours in NanoSeconds
const OneMinute = BigInt(60000000000); // 1 minute in Nanoseconds

const OneDayMS = 86400000; // 24 hours in NanoSeconds

const base64ToUInt8Array = (base64String: string): Uint8Array => {
  return Buffer.from(base64String, 'base64');
};

const NNS_SUBNET_ID =
  "erfz5-i2fgp-76zf7-idtca-yam6s-reegs-x5a3a-nku2r-uqnwl-5g7cy-tqe";
const NNS_STATE_PATH = "pic/nns_state/node-100/state";


describe("test timers", () => {
  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL, {
      
      /* nns: {
        state: {
          type: SubnetStateType.FromPath,
          path: NNS_STATE_PATH,
          subnetId: Principal.fromText(NNS_SUBNET_ID),
        }
      }, */

      processingTimeoutMs: 1000 * 60 * 5,
    } );

    //await pic.setTime(new Date(2024, 1, 30).getTime());
    await pic.setTime(new Date(2024, 7, 10, 17, 55,33).getTime());
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.advanceTime(1000 * 5);

    

    await pic.resetTime();
    await pic.tick();

    //const subnets = pic.getApplicationSubnets();

    icrc75_fixture = await pic.setupCanister<ICRC75Service>({
      //targetCanisterId: Principal.fromText("q26le-iqaaa-aaaam-actsa-cai"),
      sender: admin.getPrincipal(),
      idlFactory: icrc75IDLFactory,
      wasm: sub_WASM_PATH,
      //targetSubnetId: subnets[0].id,
      arg: IDL.encode(icrc75Init({IDL}), [[]]),
    });

    //create default lists
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();
    let newLists = await icrc75_fixture.actor.icrc75_manage_list_properties([
      {
        list: "targetList",
        action: { "Create": { admin: [], metadata: [], members: [] } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "sourceList",
        action: { "Create": { admin: [], metadata: [], members: [] } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },

      {
        list: "targetList",
        action: { ChangePermissions: {Admin: { Add: {Identity : icrc75_fixture.canisterId} } } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "sourceList",
        action: { ChangePermissions: {Admin : { Add: {Identity : icrc75_fixture.canisterId} } } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      
    ]);

    console.log("newLists", JSON.stringify(newLists, replacer, 2));

    await pic.tick();

    let membersadd =await icrc75_fixture.actor.icrc75_manage_list_membership([
      {
        list: "targetList",
        action: { "Add": { "Identity": alice.getPrincipal() } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "targetList",
        action: { "Add": { "Identity": bob.getPrincipal() } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "targetList",
        action: { "Add": { "Identity": charlie.getPrincipal() } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "sourceList",
        action: { "Add": { "Identity": dan.getPrincipal() } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "sourceList",
        action: { "Add": { "Identity": edina.getPrincipal() } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      },
      {
        list: "sourceList",
        action: { "Add": { "Identity": frank.getPrincipal() } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      }
    ]
    );

    console.log("membersadd", JSON.stringify(membersadd, replacer, 2)); 

    await pic.tick();
  });


  afterEach(async () => {
    await pic.tearDown();
  });

  

  let createList = async (listName: string = "testListName") => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();

    const createResponse = await icrc75_fixture.actor.icrc75_manage_list_properties([
      {
        list: listName,
        action: { "Create": { admin: [], metadata: [], members: [] } },
        memo: [],
        from_subaccount: [],
        created_at_time: []
      }
    ]);
    await pic.tick();
    return createResponse;
  };

  it('should swap all', async () => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();

    console.log("swap all");
  
    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.icrc104_apply_rules( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceAll",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    console.log("ruleResponse", JSON.stringify(ruleResponse, replacer, 2));

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();


    if(!(ruleResponse && "Ok" in ruleResponse && "LocalTrx" in ruleResponse.Ok)){
      throw new Error("Rule response not found");
    };
  
    expect(ruleResponse).toBeDefined();
    expect(ruleResponse).toHaveProperty("Ok");

    expect(ruleResponse.Ok.LocalTrx.transactions.length).toEqual(6);
  
    let updatedList = await icrc75_fixture.actor.icrc75_get_list_members_admin("targetList", [], []);

    console.log("updatedList", JSON.stringify(updatedList, replacer, 2));

    expect(updatedList).toContainEqual({"Identity": dan.getPrincipal()});
    expect(updatedList).toContainEqual({"Identity": edina.getPrincipal()});
    expect(updatedList).toContainEqual({"Identity": frank.getPrincipal()});

  });

  it('should swap one', async () => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();
  
    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.icrc104_apply_rules( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceOne",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();


    if(!(ruleResponse && "Ok" in ruleResponse && "LocalTrx" in ruleResponse.Ok)){
      throw new Error("Rule response not found");
    };
  
    expect(ruleResponse).toBeDefined();
    expect(ruleResponse).toHaveProperty("Ok");

    expect(ruleResponse.Ok.LocalTrx.transactions.length).toEqual(2);
  
    let updatedList = await icrc75_fixture.actor.icrc75_get_list_members_admin("targetList", [], []);

    let bOriginal = 0;
    let bNew = 0;

    for (let i = 0; i < updatedList.length; i++) {
      const item = updatedList[i];
      if ('Identity' in item && item.Identity.toString() === alice.getPrincipal().toString()) {
        bOriginal++;
      };
      if ('Identity' in item && item.Identity.toString() === bob.getPrincipal().toString()) {
        bOriginal++;
      };
      if ('Identity' in item && item.Identity.toString() === charlie.getPrincipal().toString()) {
        bOriginal++;
      };

      if ('Identity' in item && item.Identity.toString() === dan.getPrincipal().toString()) {
        bNew++;
      };
      if ('Identity' in item && item.Identity.toString() === edina.getPrincipal().toString()) {
        bNew++;
      };
      if ('Identity' in item && item.Identity.toString() === frank.getPrincipal().toString()) {
        bNew++;
      };
    }

    expect(bOriginal).toEqual(2);
    expect(bNew).toEqual(1);
  });


  it('should swap None', async () => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();
  
    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.icrc104_apply_rules( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceNone",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();

    console.log("ruleResponse", JSON.stringify(ruleResponse, replacer, 2));


    if(!(ruleResponse && "Err" in ruleResponse && "ExecutionFailed" in ruleResponse.Err)){
      throw new Error("Rule response not found");
    };
  
    expect(ruleResponse).toBeDefined();
    expect(ruleResponse).toHaveProperty("Err");

    expect(ruleResponse.Err.ExecutionFailed).toEqual("no qualifiying members for replacement");
  
    let updatedList = await icrc75_fixture.actor.icrc75_get_list_members_admin("targetList", [], []);

    let bOriginal = 0;
    let bNew = 0;

    for (let i = 0; i < updatedList.length; i++) {
      const item = updatedList[i];
      if ('Identity' in item && item.Identity.toString() === alice.getPrincipal().toString()) {
        bOriginal++;
      };
      if ('Identity' in item && item.Identity.toString() === bob.getPrincipal().toString()) {
        bOriginal++;
      };
      if ('Identity' in item && item.Identity.toString() === charlie.getPrincipal().toString()) {
        bOriginal++;
      };

      if ('Identity' in item && item.Identity.toString() === dan.getPrincipal().toString()) {
        bNew++;
      };
      if ('Identity' in item && item.Identity.toString() === edina.getPrincipal().toString()) {
        bNew++;
      };
      if ('Identity' in item && item.Identity.toString() === frank.getPrincipal().toString()) {
        bNew++;
      };
    }

    expect(bOriginal).toEqual(3);
    expect(bNew).toEqual(0);
  });


  it('should swap None for non-qualify', async () => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();
  
    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.icrc104_apply_rules( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceNonQualify",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();


    if(!(ruleResponse && "Err" in ruleResponse && "ExecutionFailed" in ruleResponse.Err)){
      throw new Error("Rule response not found");
    };
  
    expect(ruleResponse).toBeDefined();
    expect(ruleResponse).toHaveProperty("Err");

    expect(ruleResponse.Err.ExecutionFailed).toEqual("not qualifying");
  
    let updatedList = await icrc75_fixture.actor.icrc75_get_list_members_admin("targetList", [], []);

    let bOriginal = 0;
    let bNew = 0;

    for (let i = 0; i < updatedList.length; i++) {
      const item = updatedList[i];
      if ('Identity' in item && item.Identity.toString() === alice.getPrincipal().toString()) {
        bOriginal++;
      };
      if ('Identity' in item && item.Identity.toString() === bob.getPrincipal().toString()) {
        bOriginal++;
      };
      if ('Identity' in item && item.Identity.toString() === charlie.getPrincipal().toString()) {
        bOriginal++;
      };

      if ('Identity' in item && item.Identity.toString() === dan.getPrincipal().toString()) {
        bNew++;
      };
      if ('Identity' in item && item.Identity.toString() === edina.getPrincipal().toString()) {
        bNew++;
      };
      if ('Identity' in item && item.Identity.toString() === frank.getPrincipal().toString()) {
        bNew++;
      };
    }

    expect(bOriginal).toEqual(3);
    expect(bNew).toEqual(0);
  });


  it('should hit custom validation', async () => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();
  
    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.validateApplyRule( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceNonQualify",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();


    if(!(ruleResponse && "Ok" in ruleResponse)){
      throw new Error("Rule response not found");
    };
  
    expect(ruleResponse).toBeDefined();
    expect(ruleResponse).toHaveProperty("Ok");

    expect(ruleResponse.Ok).toEqual("Valid Submission");
  
  });

  it('should use default validation', async () => {
    icrc75_fixture.actor.setIdentity(admin);
    await pic.tick();
  
    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.validateApplyRule( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceAll",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();


    if(!(ruleResponse && "Ok" in ruleResponse && ruleResponse.Ok.indexOf("Apply the rule ") === 0)){
      console.log("ruleResponse", JSON.stringify(ruleResponse, replacer, 2));
      throw new Error("Rule response not found");
    };

  });


  it('should use reject validation', async () => {
    icrc75_fixture.actor.setIdentity(alice);
    await pic.tick();

    // Create a list named "uniqueList1"
    const ruleResponse = await icrc75_fixture.actor.validateApplyRule( {
      icrc75Canister : icrc75_fixture.canisterId,
      target_list: "targetList",                     // The list to apply rules on
      members: [],                // Optional identity triggering the rule application
      rule_namespace: "replaceAll",     // Namespace identifying the rule set to apply
      metadata: [], 
    });

    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();
    await pic.tick();


    if(!(ruleResponse && "Err" in ruleResponse && ruleResponse.Err.indexOf("caller not authorize") === 0)){
      console.log("ruleResponse", JSON.stringify(ruleResponse, replacer, 2));
      throw new Error("Rule response not found");
    };

  });



});
