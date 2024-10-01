


# RoleRotator

RoleRotator is a Motoko library designed for the Internet Computer that provides functionality to rotate roles (or list memberships) within an [ICRC-75](#icrc-75-minimal-membership-standard) compliant membership list. It leverages the [ICRC-104](#icrc-104-rule-based-membership-manager-standard) standard to define and apply rule-based membership management, enabling developers to automate the process of rotating roles or memberships within their applications.

## Introduction

RoleRotator is designed to help developers manage and rotate roles or memberships within their decentralized applications on the Internet Computer. By leveraging the ICRC-75 and ICRC-104 standards, it provides a standardized and interoperable way to handle membership lists and apply rules for role rotation.

Whether you need to rotate committee members, assign random roles, or manage any list-based memberships, RoleRotator provides the tools to do so efficiently and securely.

## Features

- **Role Rotation**: Automate the rotation of roles or memberships within a list.
- **Customizable Rules**: Define custom qualification functions to determine eligibility for role rotation.
- **ICRC-75 Compliant**: Uses the ICRC-75 standard for minimal membership management.
- **ICRC-104 Compliant**: Implements the ICRC-104 standard for rule-based membership management.
- **Interoperability**: Seamlessly integrate with other canisters and services that implement ICRC standards.

## Prerequisites

- Knowledge of the [Motoko](https://internetcomputer.org/docs/current/developer-docs/build/languages/motoko/) programming language.
- Understanding of the [Internet Computer](https://internetcomputer.org/) and its canister model.
- Familiarity with ICRC standards ([ICRC-75](https://github.com/dfinity/ICRC/issues/75) and [ICRC-104](https://github.com/dfinity/ICRC/issues/104)) is helpful.

## Installation

To use RoleRotator in your project, use mops.

```bash
mops add af-role-rotator
```

Include the `RoleRotator` module in your Motoko code:

```motoko
import RoleRotator "mo:af-role-rotator";
```

Ensure that you have access to the necessary dependencies, such as `ICRC75`, `ICRC104`, and others.

## Usage

### Initializing RoleRotator

To create an instance of `RoleRotator`, you need to provide the necessary initialization arguments:

```motoko
let roleRotator = RoleRotator.RoleRotator({
    canister = Principal.fromActor(this); // The canister where RoleRotator is deployed
    icrc75 = ?icrc75Instance;             // An instance of ICRC75 if available
    icrc104 = icrc104Instance;            // An instance of ICRC104
    qualifyFunction = ?qualifyFunction;   // A custom qualification function
    ruleNamespace = "your.rule.namespace"; // A unique namespace for your rules
    eligibleList = "yourEligibleList";     // The name of the eligible list
});
```

- **`canister`**: The principal of the canister where RoleRotator is deployed.
- **`icrc75`**: An optional instance of ICRC75. If not provided, RoleRotator will interact with a remote ICRC75 canister.
- **`icrc104`**: An instance of ICRC104 required for applying rules.
- **`qualifyFunction`**: An optional custom function to determine eligible members for rotation.
- **`ruleNamespace`**: A unique namespace identifier for your rule set.
- **`eligibleList`**: The name of the list containing eligible members.

### Defining a Qualify Function

The `qualifyFunction` is a custom function that determines which members are eligible for role rotation. It should match the `QualifyFunction` type:

```motoko
public type QualifyFunctionResponse = Star.Star<[ICRC75.ListItem], ICRC104.RuleHandlerResponse>;

public type QualifyFunction = ([ICRC75.ListItem], ICRC104.HandleRuleEvent, Bool) -> async*  (QualifyFunctionResponse);
```

Example of a simple qualify function that allows all members:

```motoko
private func qualify_all_members(
    foundMembers: [ICRC75.ListItem],
    event: ICRC104.HandleRuleEvent,
    bAwaited: Bool
) : async* RoleRotator.QualifyFunctionResponse {
    return #trappable(foundMembers);
}
```

In this example, the function simply returns all found members as eligible for rotation.

### Applying Rules

To apply the role rotation rules, you want to instantiate your class and pass in an ICRC-104 instance. The ICRC-104 instance will take care of calling the function at the appropriate time.

## Example

Here's an example of how to use RoleRotator in a canister with ICRC-104:

```motoko
import RoleRotator ".";
import ICRC104 "../../icrc104.mo/src";
import ICRC75 "../../icrc75.mo/src";
import Principal "mo:base/Principal";
import D "mo:base/Debug";

actor class Token() = this {
    // Initialize ICRC104 and ICRC75 instances
    let icrc104Instance = ICRC104.ICRC104(...);
    let icrc75Instance = ICRC75.ICRC75(...);

    // Define a qualify function
    private func qualify_replacement(
        foundMembers: [ICRC75.ListItem],
        event: ICRC104.HandleRuleEvent,
        bAwaited: Bool
    ) : async* RoleRotator.QualifyFunctionResponse {
        // Custom qualification logic
        if (/* some condition */) {
            return #awaited([selectedMembersForRotation]);
        } else {
            return #err(#awaited(#apply(#Err(#ExecutionFailed("Not qualified for rotation")))));
        }
    };

    // Initialize RoleRotator
    let roleRotator = RoleRotator.RoleRotator({
        canister = Principal.fromActor(this);
        icrc75 = ?icrc75Instance;
        icrc104 = icrc104Instance;
        qualifyFunction = ?qualify_market_maker_replacement;
        ruleNamespace = "com.yourco.role_replacer.rule1";
        eligibleList = "com.yourco.eligible_members";
    });

    // Apply rules
    public shared(msg) func icrc104_apply_rules(request: ICRC104Service.ApplyRuleRequest) : async ICRC104Service.ApplyRuleResult {
        D.print("Applying rules");
        await* icrc104Instance.apply_rule_handler(msg.caller, request);
    };
};
```

In this example:

- We create instances of `ICRC104` and `ICRC75`.
- We define a custom `qualify_replacement` function to determine eligibility.
- We initialize `RoleRotator` with the required parameters.
- We expose a shared function `icrc104_apply_rules` to handle rule applications.

## ICRC Standards

RoleRotator leverages the following ICRC standards:

### ICRC-75: Minimal Membership Standard

ICRC-75 defines a minimal standard for managing membership lists on the Internet Computer. It provides data types and functions for handling identities, lists, permissions, and more.

Key features of ICRC-75:

- Defines `Identity`, `Account`, `DataItem`, `List`, and `Permission` types.
- Provides functions for managing list memberships and properties.
- Supports hierarchical list structures and permissions.

For more information, refer to the [ICRC-75 Standard](https://github.com/dfinity/ICRC/issues/75).

### ICRC-104: Rule-Based Membership Manager Standard

ICRC-104 introduces a standard for rule-based membership management. It allows developers to define and apply rules to membership lists, enabling automated and customizable membership operations.

Key features of ICRC-104:

- Defines `RuleSetNamespace` and `ICRC75Change` types.
- Provides functions for applying and simulating rules on membership lists.
- Supports integration with ICRC-75 compliant canisters.

For more information, refer to the [ICRC-104 Standard](https://github.com/dfinity/ICRC/issues/104).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Funding provided by [DFINITY Foundation](https://dfinity.org/) for the Internet Computer.
- Contributors to the ICRC standards.
- Community members who provided feedback and contributions.

# Additional Information

- **Dependencies**: Ensure that you have the necessary dependencies, including `ICRC104`, `ICRC75`, and any other modules referenced in the code.
- **Custom Implementation**: The `qualifyFunction` allows for custom logic to determine which members are eligible for role rotation. This is where you can implement business-specific rules.
- **Integration**: RoleRotator is designed to be integrated into existing canisters that manage memberships or roles for DAOs. It provides the functionality to automate and manage role rotations according to defined rules. 

# Support

If you encounter any issues or have questions, please open an issue in the repository or reach out to the community for assistance.

# OVS Default Behavior

This motoko class has a default OVS behavior that sends cycles to the developer to provide funding for maintenance and continued development. In accordance with the OVS specification and ICRC85, this behavior may be overridden by another OVS sharing heuristic or turned off. We encourage all users to implement some form of OVS sharing as it helps us provide quality software and support to the community.

Default behavior: 1 XDR per 10000 rules simulated or processed per month up to 100 XDR;

Default Beneficiary: ICDevs.org

Dependent Libraries: 
  - https://mops.one/icrc104-mo

## AstroFlora

![AstroFlora](AF.png "AstroFlora" )

....coming soon....