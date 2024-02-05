import { AzureFunction, Context } from "@azure/functions"
const { ServiceBusClient } = require("@azure/service-bus");
import { parse } from 'csv-parse/sync'

const blobTrigger: AzureFunction = async function (context: Context, myBlob: any): Promise<void> {
    context.log(context.bindings.myBlob.toString());
    context.log("Blob trigger function processed blob \n Name:", context.bindingData.name, "\n Blob Size:", myBlob.length, "Bytes");

    const serviceBusConnectionString = process.env.ServiceBusConnectionString;
    const queueName = "my_new_servicebus_queue";
    const serviceBusClient = new ServiceBusClient(serviceBusConnectionString);
    const sender = serviceBusClient.createSender(queueName);

    const products = parse(context.bindings.myBlob, {
        columns: true,
        skip_empty_lines: true
    });

    try {

        await Promise.all(products.map(async product => {
            const message = {
                body: JSON.stringify(product),
                label: "product",
            };

            await sender.sendMessages(message);
        }))

        context.res = {
            status: 200,
            body: "Message sent successfully to Service Bus queue.",
        };
    } catch (error) {
        context.res = {
            status: 500,
            body: `Error sending message to Service Bus: ${error.message}`,
        };
    } finally {
        await sender.close();
        await serviceBusClient.close();
    }

};

export default blobTrigger;
