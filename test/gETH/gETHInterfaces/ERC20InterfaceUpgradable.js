// const {
//   constants,
//   expectEvent,
//   expectRevert,
// } = require("@openzeppelin/test-helpers");
// const { BigNumber } = require("ethers");
// const { expect } = require("chai");
// const { ZERO_ADDRESS } = constants;

// describe("ERC20", function (accounts) {
//   const errorPrefix = "ERC20";

//   const initialSupply = BigNumber.from(100);
//   let initialHolder;
//   let recipient;
//   let anotherAccount;
//   let token;
//   const symbol = "gETH";
//   const name = "Token Geode Staked Ether";
//   const unknownTokenId = "6969";

//   const setupTest = deployments.createFixture(async (hre) => {
//     ({ ethers, web3, Web3 } = hre);

//     const signers = await ethers.getSigners();
//     initialHolder = minter = signers[0].address;
//     recipient = signers[1].address;
//     anotherAccount = signers[2].address;

//     const gETHFac = await ethers.getContractFactory("gETH");
//     gETH = await gETHFac.deploy("initialURI");

//     ERC20InterfaceFac = await ethers.getContractFactory(
//       "ERC20InterfaceUpgradable"
//     );

//     const getBytes32 = (x) => {
//       return ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 32);
//     };

//     const getBytes = (key) => {
//       return Web3.utils.toHex(key);
//     };
//     const nameBytes = getBytes(name).substr(2);
//     const symbolBytes = getBytes(symbol).substr(2);
//     const interfaceData =
//       getBytes32(nameBytes.length / 2) + nameBytes + symbolBytes;
//     ERC20Interface = await ERC20InterfaceFac.deploy();

//     await ERC20Interface.initialize(
//       unknownTokenId,
//       gETH.address,
//       interfaceData
//     );
//     await gETH
//       .connect(signers[0])
//       .setInterface(ERC20Interface.address, unknownTokenId, true);
//     await gETH
//       .connect(signers[0])
//       .mint(initialHolder, unknownTokenId, initialSupply.toString(), "0x");
//     token = ERC20Interface;
//   });

//   beforeEach(async function () {
//     await setupTest();
//   });

//   it("has a name", async function () {
//     expect(await token.name()).to.equal(name);
//   });

//   it("has a symbol", async function () {
//     expect(await token.symbol()).to.equal(symbol);
//   });

//   it("has 18 decimals", async function () {
//     expect(await token.decimals()).to.be.eq(18);
//   });

//   describe("total supply", function () {
//     it("returns the total amount of tokens", async function () {
//       expect(await token.totalSupply()).to.be.eq(initialSupply);
//     });
//   });

//   describe("balanceOf", function () {
//     describe("when the requested account has no tokens", function () {
//       it("returns zero", async function () {
//         expect(await token.balanceOf(anotherAccount)).to.be.eq("0");
//       });
//     });

//     describe("when the requested account has some tokens", function () {
//       it("returns the total amount of tokens", async function () {
//         expect(await token.balanceOf(initialHolder)).to.be.eq(initialSupply);
//       });
//     });
//   });

//   describe("transfer", function () {
//     describe("when the recipient is not the zero address", function () {
//       describe("when the sender does not have enough balance", function () {
//         const amount = BigNumber.from(initialSupply).add(1);
//         it("reverts", async function () {
//           await expectRevert(
//             token.transfer(initialHolder, recipient, amount),
//             `${errorPrefix}: transfer amount exceeds balance`
//           );
//         });
//       });

//       describe("when the sender transfers all balance", function () {
//         const amount = initialSupply;

//         it("transfers the requested amount", async function () {
//           await token.transfer(initialHolder, recipient, amount);

//           expect(await token.balanceOf(from)).to.be.eq("0");

//           expect(await token.balanceOf(to)).to.be.eq(amount);
//         });

//         it("emits a transfer event", async function () {
//           expectEvent(
//             await token.transfer(initialHolder, recipient, amount),
//             "Transfer",
//             {
//               initialHolder,
//               recipient,
//               value: amount,
//             }
//           );
//         });
//       });

//       describe("when the sender transfers zero tokens", function () {
//         const amount = BigNumber.from("0");

//         it("transfers the requested amount", async function () {
//           await token.transfer(initialHolder, recipient, amount);

//           expect(await token.balanceOf(from)).to.be.eq(initialSupply);

//           expect(await token.balanceOf(to)).to.be.eq("0");
//         });

//         it("emits a transfer event", async function () {
//           expectEvent(
//             await token.transfer(initialHolder, recipient, amount),
//             "Transfer",
//             {
//               initialHolder,
//               recipient,
//               value: amount,
//             }
//           );
//         });
//       });
//     });

//     describe("when the recipient is the zero address", function () {
//       it("reverts", async function () {
//         await expectRevert(
//           token.transfer(initialHolder, ZERO_ADDRESS, initialSupply),
//           `${errorPrefix}: transfer to the zero address`
//         );
//       });
//     });
//   });

//   describe("transfer from", function () {
//     const spender = recipient;

//     describe("when the token owner is not the zero address", function () {
//       const tokenOwner = initialHolder;

//       describe("when the recipient is not the zero address", function () {
//         const to = anotherAccount;

//         describe("when the spender has enough allowance", function () {
//           beforeEach(async function () {
//             await token.approve(recipient, initialSupply, {
//               from: initialHolder,
//             });
//           });

//           describe("when the token owner has enough balance", function () {
//             const amount = initialSupply;

//             it("transfers the requested amount", async function () {
//               await token.transferFrom(tokenOwner, recipient, amount, {
//                 from: recipient,
//               });

//               expect(await token.balanceOf(tokenOwner)).to.be.eq("0");

//               expect(await token.balanceOf(to)).to.be.eq(amount);
//             });

//             it("decreases the spender allowance", async function () {
//               await token.transferFrom(tokenOwner, recipient, amount, {
//                 from: recipient,
//               });

//               expect(await token.allowance(tokenOwner, spender)).to.be.eq("0");
//             });

//             it("emits a transfer event", async function () {
//               expectEvent(
//                 await token.transferFrom(tokenOwner, recipient, amount, {
//                   from: recipient,
//                 }),
//                 "Transfer",
//                 {
//                   from: tokenOwner,
//                   to: recipient,
//                   value: amount,
//                 }
//               );
//             });

//             it("emits an approval event", async function () {
//               expectEvent(
//                 await token.transferFrom(tokenOwner, recipient, amount, {
//                   from: recipient,
//                 }),
//                 "Approval",
//                 {
//                   owner: tokenOwner,
//                   spender: recipient,
//                   value: await token.allowance(tokenOwner, spender),
//                 }
//               );
//             });
//           });

//           describe("when the token owner does not have enough balance", function () {
//             const amount = initialSupply;

//             beforeEach("reducing balance", async function () {
//               await token.transfer(recipient, 1, { from: tokenOwner });
//             });

//             it("reverts", async function () {
//               await expectRevert(
//                 token.transferFrom(tokenOwner, recipient, amount, {
//                   from: recipient,
//                 }),
//                 `${errorPrefix}: transfer amount exceeds balance`
//               );
//             });
//           });
//         });

//         describe("when the spender does not have enough allowance", function () {
//           const allowance = BigNumber.from(initialSupply).sub(1);

//           beforeEach(async function () {
//             await token.approve(recipient, allowance, { from: tokenOwner });
//           });

//           describe("when the token owner has enough balance", function () {
//             const amount = initialSupply;

//             it("reverts", async function () {
//               await expectRevert(
//                 token.transferFrom(tokenOwner, recipient, amount, {
//                   from: recipient,
//                 }),
//                 `${errorPrefix}: insufficient allowance`
//               );
//             });
//           });

//           describe("when the token owner does not have enough balance", function () {
//             const amount = allowance;

//             beforeEach("reducing balance", async function () {
//               await token.transfer(recipient, 2, { from: tokenOwner });
//             });

//             it("reverts", async function () {
//               await expectRevert(
//                 token.transferFrom(tokenOwner, recipient, amount, {
//                   from: recipient,
//                 }),
//                 `${errorPrefix}: transfer amount exceeds balance`
//               );
//             });
//           });
//         });

//         describe("when the spender has unlimited allowance", function () {
//           beforeEach(async function () {
//             await token.approve(recipient, MAX_UINT256, {
//               from: initialHolder,
//             });
//           });

//           it("does not decrease the spender allowance", async function () {
//             await token.transferFrom(tokenOwner, recipient, 1, {
//               from: recipient,
//             });

//             expect(await token.allowance(tokenOwner, spender)).to.be.eq(
//               MAX_UINT256
//             );
//           });

//           it("does not emit an approval event", async function () {
//             expectEvent.notEmitted(
//               await token.transferFrom(tokenOwner, recipient, 1, {
//                 from: recipient,
//               }),
//               "Approval"
//             );
//           });
//         });
//       });

//       describe("when the recipient is the zero address", function () {
//         const amount = initialSupply;
//         const to = ZERO_ADDRESS;

//         beforeEach(async function () {
//           await token.approve(recipient, amount, { from: tokenOwner });
//         });

//         it("reverts", async function () {
//           await expectRevert(
//             token.transferFrom(tokenOwner, recipient, amount, {
//               from: recipient,
//             }),
//             `${errorPrefix}: transfer to the zero address`
//           );
//         });
//       });
//     });

//     describe("when the token owner is the zero address", function () {
//       const amount = 0;
//       const tokenOwner = ZERO_ADDRESS;
//       const to = recipient;

//       it("reverts", async function () {
//         await expectRevert(
//           token.transferFrom(tokenOwner, recipient, amount, { from: spender }),
//           "from the zero address"
//         );
//       });
//     });
//   });

//   describe("approve", function () {
//     describe("when the spender is not the zero address", function () {
//       describe("when the sender has enough balance", function () {
//         const amount = initialSupply;

//         it("emits an approval event", async function () {
//           expectEvent(
//             await token.transfer(initialHolder, recipient, amount),
//             "Approval",
//             {
//               owner: initialHolder,
//               spender: recipient,
//               value: amount,
//             }
//           );
//         });

//         describe("when there was no approved amount before", function () {
//           it("approves the requested amount", async function () {
//             await token.transfer(initialHolder, recipient, amount);

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               amount
//             );
//           });
//         });

//         describe("when the spender had an approved amount", function () {
//           beforeEach(async function () {
//             await token.transfer(initialHolder, recipient, BigNumber.from(1));
//           });

//           it("approves the requested amount and replaces the previous one", async function () {
//             await token.transfer(initialHolder, recipient, amount);

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               amount
//             );
//           });
//         });
//       });

//       describe("when the sender does not have enough balance", function () {
//         const amount = BigNumber.from(initialSupply).add(1);

//         it("emits an approval event", async function () {
//           expectEvent(
//             await token.transfer(initialHolder, recipient, amount),
//             "Approval",
//             {
//               owner: initialHolder,
//               spender: recipient,
//               value: amount,
//             }
//           );
//         });

//         describe("when there was no approved amount before", function () {
//           it("approves the requested amount", async function () {
//             await token.transfer(initialHolder, recipient, amount);

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               amount
//             );
//           });
//         });

//         describe("when the spender had an approved amount", function () {
//           beforeEach(async function () {
//             await token.transfer(initialHolder, recipient, BigNumber.from(1));
//           });

//           it("approves the requested amount and replaces the previous one", async function () {
//             await token.transfer(initialHolder, recipient, amount);

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               amount
//             );
//           });
//         });
//       });
//     });

//     describe("when the spender is the zero address", function () {
//       it("reverts", async function () {
//         await expectRevert(
//           token.transfer(initialHolder, ZERO_ADDRESS, initialSupply),
//           `${errorPrefix}: approve to the zero address`
//         );
//       });
//     });
//   });

//   describe("decrease allowance", function () {
//     describe("when the spender is not the zero address", function () {
//       const spender = recipient;

//       function shouldDecreaseApproval(amount) {
//         describe("when there was no approved amount before", function () {
//           it("reverts", async function () {
//             await expectRevert(
//               token.decreaseAllowance(recipient, amount, {
//                 from: initialHolder,
//               }),
//               "ERC20: decreased allowance below zero"
//             );
//           });
//         });

//         describe("when the spender had an approved amount", function () {
//           const approvedAmount = amount;

//           beforeEach(async function () {
//             await token.approve(recipient, approvedAmount, {
//               from: initialHolder,
//             });
//           });

//           it("emits an approval event", async function () {
//             expectEvent(
//               await token.decreaseAllowance(recipient, approvedAmount, {
//                 from: initialHolder,
//               }),
//               "Approval",
//               {
//                 owner: initialHolder,
//                 spender: recipient,
//                 value: BigNumber.from(0),
//               }
//             );
//           });

//           it("decreases the spender allowance subtracting the requested amount", async function () {
//             await token.decreaseAllowance(
//               recipient,
//               BigNumber.from(approvedAmount).sub(1),
//               {
//                 from: initialHolder,
//               }
//             );

//             expect(await token.allowance(initialHolder, spender)).to.be.eq("1");
//           });

//           it("sets the allowance to zero when all allowance is removed", async function () {
//             await token.decreaseAllowance(recipient, approvedAmount, {
//               from: initialHolder,
//             });
//             expect(await token.allowance(initialHolder, spender)).to.be.eq("0");
//           });

//           it("reverts when more than the full allowance is removed", async function () {
//             await expectRevert(
//               token.decreaseAllowance(
//                 recipient,
//                 BigNumber.from(approvedAmount).add(1),
//                 {
//                   from: initialHolder,
//                 }
//               ),
//               "ERC20: decreased allowance below zero"
//             );
//           });
//         });
//       }

//       describe("when the sender has enough balance", function () {
//         const amount = initialSupply;

//         shouldDecreaseApproval(amount);
//       });

//       describe("when the sender does not have enough balance", function () {
//         const amount = BigNumber.from(initialSupply).add(1);

//         shouldDecreaseApproval(amount);
//       });
//     });

//     describe("when the spender is the zero address", function () {
//       const amount = initialSupply;
//       const spender = ZERO_ADDRESS;

//       it("reverts", async function () {
//         await expectRevert(
//           token.decreaseAllowance(recipient, amount, {
//             from: initialHolder,
//           }),
//           "ERC20: decreased allowance below zero"
//         );
//       });
//     });
//   });

//   describe("increase allowance", function () {
//     const amount = initialSupply;

//     describe("when the spender is not the zero address", function () {
//       const spender = recipient;

//       describe("when the sender has enough balance", function () {
//         it("emits an approval event", async function () {
//           expectEvent(
//             await token.increaseAllowance(recipient, amount, {
//               from: initialHolder,
//             }),
//             "Approval",
//             {
//               owner: initialHolder,
//               spender: recipient,
//               value: amount,
//             }
//           );
//         });

//         describe("when there was no approved amount before", function () {
//           it("approves the requested amount", async function () {
//             await token.increaseAllowance(recipient, amount, {
//               from: initialHolder,
//             });

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               amount
//             );
//           });
//         });

//         describe("when the spender had an approved amount", function () {
//           beforeEach(async function () {
//             await token.approve(recipient, BigNumber.from(1), {
//               from: initialHolder,
//             });
//           });

//           it("increases the spender allowance adding the requested amount", async function () {
//             await token.increaseAllowance(recipient, amount, {
//               from: initialHolder,
//             });

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               BigNumber.from(amount).add(1)
//             );
//           });
//         });
//       });

//       describe("when the sender does not have enough balance", function () {
//         const amount = BigNumber.from(initialSupply).add(1);

//         it("emits an approval event", async function () {
//           expectEvent(
//             await token.increaseAllowance(recipient, amount, {
//               from: initialHolder,
//             }),
//             "Approval",
//             {
//               owner: initialHolder,
//               spender: recipient,
//               value: amount,
//             }
//           );
//         });

//         describe("when there was no approved amount before", function () {
//           it("approves the requested amount", async function () {
//             await token.increaseAllowance(recipient, amount, {
//               from: initialHolder,
//             });

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               amount
//             );
//           });
//         });

//         describe("when the spender had an approved amount", function () {
//           beforeEach(async function () {
//             await token.approve(recipient, BigNumber.from(1), {
//               from: initialHolder,
//             });
//           });

//           it("increases the spender allowance adding the requested amount", async function () {
//             await token.increaseAllowance(recipient, amount, {
//               from: initialHolder,
//             });

//             expect(await token.allowance(initialHolder, spender)).to.be.eq(
//               BigNumber.from(amount).add(1)
//             );
//           });
//         });
//       });
//     });

//     describe("when the spender is the zero address", function () {
//       const spender = ZERO_ADDRESS;

//       it("reverts", async function () {
//         await expectRevert(
//           token.increaseAllowance(recipient, amount, {
//             from: initialHolder,
//           }),
//           "ERC20: approve to the zero address"
//         );
//       });
//     });
//   });
// });
