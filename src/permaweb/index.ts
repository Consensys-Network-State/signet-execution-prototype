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
            data: args.data,
        });

        const response = await result({ message: txId, process: args.processId.toString() });

        if (response.Error) {
            throw new Error(response.Error);
        }

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

export async function readHandler(args: {
    processId: string;
    action: string;
    tags?: TagType[];
    data?: any;
}): Promise<any> {
    const tags = [AgreementTag, { name: 'Action', value: args.action }];

    if (args.tags) tags.push(...args.tags);
    const data = JSON.stringify(args.data || {});

    const response = await dryrun({
        process: args.processId,
        tags: tags,
        data: data,
    });

    if (response.Error) {
        throw new Error(response.Error);
    }

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
                { name: 'Action', value: 'Eval' },
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