import { createDataItemSigner, dryrun, message, result, results, spawn } from '@permaweb/aoconnect';
import {
    TagType,
} from '@/permaweb/types';
import { getTagValue } from '@/permaweb/utils';

const AgreementTag = { name: 'DocumentType', value: 'AgreementDocument' };

export async function messageResult(args: {
    processId: string;
    wallet: any;
    action: string;
    tags: TagType[] | [];
    data: any;
    useRawData?: boolean;
}): Promise<any> {
    try {
        const txId = await message({
            process: args.processId,
            tags: [
              { name: "Action", value: args.action },
                ...args.tags,
            ],
            signer: createDataItemSigner(args.wallet),
            data: JSON.stringify(args.data),
        });

        const response = await result({ message: txId, process: args.processId.toString() });
        const { Messages } = response;

        if (Messages?.length) {
            const response = {};

            for (const message of Messages) {
                const action = getTagValue(message.Tags, 'Action') || args.action;

                let responseData = null;
                const messageData = message.Data;

                if (messageData) {
                    try {
                        responseData = JSON.parse(messageData);
                    } catch {
                        responseData = messageData;
                    }
                }

                const responseStatus = getTagValue(message.Tags, 'Status');
                const responseMessage = getTagValue(message.Tags, 'Message');

                response[action] = {
                    id: txId,
                    status: responseStatus,
                    message: responseMessage,
                    data: responseData,
                };
            }

            return response;
        }

        if (response.Output) {
            return response.Output;
        }

        return null;
    } catch (e) {
        console.error(e);
    }
}

export async function messageResults(args: {
    processId: string;
    wallet: any;
    action: string;
    tags: TagType[] | null;
    data: any;
    responses?: string[];
    handler?: string;
}): Promise<any> {
    try {
        const tags = [{ name: 'Action', value: args.action }];
        if (args.tags) tags.push(...args.tags);

        await message({
            process: args.processId,
            signer: createDataItemSigner(args.wallet),
            tags: tags,
            data: JSON.stringify(args.data),
        });

        await new Promise((resolve) => setTimeout(resolve, 1000));

        const messageResults = await results({
            process: args.processId,
            sort: 'DESC',
            limit: 100,
        });

        if (messageResults?.edges?.length) {
            const response = {};

            for (const result of messageResults.edges) {
                if (result.node?.Messages?.length) {
                    const resultSet = [args.action];
                    if (args.responses) resultSet.push(...args.responses);

                    for (const message of result.node.Messages) {
                        const action = getTagValue(message.Tags, 'Action');

                        if (action) {
                            let responseData = null;
                            const messageData = message.Data;

                            if (messageData) {
                                try {
                                    responseData = JSON.parse(messageData);
                                } catch {
                                    responseData = messageData;
                                }
                            }

                            const responseStatus = getTagValue(message.Tags, 'Status');
                            const responseMessage = getTagValue(message.Tags, 'Message');

                            if (action === 'Action-Response') {
                                const responseHandler = getTagValue(message.Tags, 'Handler');
                                if (args.handler && args.handler === responseHandler) {
                                    response[action] = {
                                        status: responseStatus,
                                        message: responseMessage,
                                        data: responseData,
                                    };
                                }
                            } else {
                                if (resultSet.includes(action)) {
                                    response[action] = {
                                        status: responseStatus,
                                        message: responseMessage,
                                        data: responseData,
                                    };
                                }
                            }

                            if (Object.keys(response).length === resultSet.length) break;
                        }
                    }
                }
            }

            return response;
        }

        return null;
    } catch (e) {
        console.error(e);
    }
}

export async function readHandler(args: {
    processId: string;
    action: string;
    tags?: TagType[];
    data?: any;
}): Promise<any> {
    // const tags = [{ name: 'Action', value: args.action }];
    const tags = [AgreementTag];
    

    if (args.tags) tags.push(...args.tags);
    const data = JSON.stringify(args.data || {});

    const response = await dryrun({
        process: args.processId,
        tags: tags,
        data: data,
    });

    console.log(response);

    if (response.Messages?.length) {
        if (response.Messages[0].Data) {
            return JSON.parse(response.Messages[0].Data);
        }
        if (response.Messages[0].Tags) {
            return response.Messages[0].Tags.reduce((acc: any, item: any) => {
                acc[item.name] = item.value;
                return acc;
            }, {});
        }
    }
}

export async function spawnProcess(args: {
    wallet: any;
    module: string;
    tags?: TagType[];
    data?: any;
}): Promise<{ processId: string } | null> {
    try {
        const processId = await spawn({
            module: args.module,
            scheduler: process.env.SCHEDULER,
            signer: createDataItemSigner(args.wallet),
            tags: [
                AgreementTag,
                { name: "Authority", value: process.env.MU },
                ...(args.tags ? args.tags : [])
            ],
            data: JSON.stringify(args.data || {}),
        });

        if (!processId) {
            throw new Error('Failed to spawn process - no processId returned');
        }
        return { processId };
    } catch (error) {
        console.error('Error spawning process:', error);
        return null;
    }
}