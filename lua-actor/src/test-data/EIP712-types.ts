// EIP-712 types matching our grant-agreement.md.dfsm.json example agreement
export const EIP712_TYPES = {
    EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" }
    ],
    CredentialSubject: [
        { name: "agreement", type: "Agreement" },
        { name: "id", type: "string" }
    ],
    Agreement: [
        { name: "content", type: "Content" },
        { name: "execution", type: "Execution" },
        { name: "metadata", type: "Metadata" },
        { name: "variables", type: "Variables[]" }
    ],
    Content: [
        { name: "data", type: "string" },
        { name: "type", type: "string" }
    ],
    Execution: [
        { name: "data", type: "Data" },
        { name: "type", type: "string" }
    ],
    Data: [
        { name: "inputs", type: "Inputs" },
        { name: "states", type: "string[]" },
        { name: "transitions", type: "Transitions[]" }
    ],
    Inputs: [
        { name: "grantRecipientSignature", type: "GrantRecipientSignature" },
        { name: "workApprovedSignature", type: "WorkApprovedSignature" }
        { name: "workRejectedSignature", type: "WorkRejectedSignature" }
    ],
    GrantRecipientSignature: [
        { name: "description", type: "string" },
        { name: "displayName", type: "string" },
        { name: "id", type: "string" },
        { name: "schema", type: "string" },
        { name: "signer", type: "string" },
        { name: "type", type: "string" },
        { name: "value", type: "Value" }
    ],
    Value: [
        { name: "approved", type: "bool" },
        { name: "type", type: "string" }
    ],
    WorkApprovedSignature: [
        { name: "description", type: "string" },
        { name: "displayName", type: "string" },
        { name: "id", type: "string" },
        { name: "schema", type: "string" },
        { name: "signer", type: "string" },
        { name: "type", type: "string" },
        { name: "value", type: "Value" }
    ],
    Transitions: [
        { name: "conditions", type: "Conditions[]" },
        { name: "from", type: "string" },
        { name: "to", type: "string" }
    ],
    Conditions: [
        { name: "inputs", type: "string[]" },
        { name: "type", type: "string" }
    ],
    Metadata: [
        { name: "author", type: "string" },
        { name: "createdAt", type: "string" },
        { name: "description", type: "string" },
        { name: "id", type: "string" },
        { name: "name", type: "string" },
        { name: "templateId", type: "string" },
        { name: "version", type: "string" }
    ],
    Variables: [
        { name: "description", type: "string" },
        { name: "id", type: "string" },
        { name: "name", type: "string" },
        { name: "type", type: "string" },
        { name: "validation", type: "Validation" },
        { name: "value", type: "string" }
    ],
    Validation: [
        { "name": "required", "type": "bool" },
        { "name": "minLength", "type": "uint256" },
        { "name": "maxLength", "type": "uint256" },
        { "name": "pattern", "type": "string" },
        { "name": "message", "type": "string" },
        { "name": "min", "type": "uint256" },
        { "name": "max", "type": "uint256" }
    ],
    Issuer: [
        { name: "id", type: "string" }
    ],
    Proof: [
        { name: "created", type: "string" },
        { name: "proofPurpose", type: "string" },
        { name: "type", type: "string" },
        { name: "verificationMethod", type: "string" }
    ],
    VerifiableCredential: [
        { name: "@context", type: "string[]" },
        { name: "credentialSubject", type: "CredentialSubject" },
        { name: "issuanceDate", type: "string" },
        { name: "issuer", type: "Issuer" },
        { name: "proof", type: "Proof" },
        { name: "type", type: "string[]" }
    ]
};