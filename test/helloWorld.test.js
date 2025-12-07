const HelloWorld = artifacts.require("HelloWorld");

contract("HelloWorld", () => {
  it("sets and reads a name", async () => {
    const instance = await HelloWorld.deployed();
    await instance.setName("User Name");
    const result = await instance.yourName();
    assert(result === "User Name", "the stored name should match");
  });
});
