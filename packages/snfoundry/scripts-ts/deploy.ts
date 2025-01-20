import {
  deployContract,
  executeDeployCalls,
  exportDeployments,
  deployer,
} from "./deploy-contract";
import { green } from "./helpers/colorize-log";

/**
 * Deploy a contract using the specified parameters.
 * **/
//@example (deploy contract with contructorArgs),
const deployScript = async (): Promise<void> => {
  await deployContract(
    {
      contract: "StarkNotes",
      contractName: "YourContract",
      constructorArgs: {
        owner: deployer.address,
        bounty_token_address:"0x4718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D",
        min_votes: 1,
        grace_length: 3,
      },
      options: {
        maxFee: BigInt(1000000000000)
      }
    }
  );
};
/**
 *
 * @example (deploy contract without contructorArgs)
 * const deployScript = async (): Promise<void> => {
 *   await deployContract(
 *     {
 *       contract: "YourContract",
 *       contractName: "YourContractExportName",
 *       options: {
 *         maxFee: BigInt(1000000000000)
 *       }
 *     }
 *   );
 * };
 *
 *
 * @returns {Promise<void>}
 */
// const deployScript = async (): Promise<void> => {
//   await deployContract({
//     contract: "StarkNotes",
//     constructorArgs: {
//       bounty_token_address:"0x4718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D",
//       min_votes: 1,
//       grace_length: 3,
//        
//     },
//   });
// };

deployScript()
  .then(async () => {
    executeDeployCalls()
      .then(() => {
        exportDeployments();
        console.log(green("All Setup Done"));
      })
      .catch((e) => {
        console.error(e);
        process.exit(1); // exit with error so that non subsequent scripts are run
      });
  })
  .catch(console.error);
