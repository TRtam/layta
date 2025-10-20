<img src="https://cdn.discordapp.com/attachments/1102451144070008863/1428594112759599174/layta-white.png?ex=68f31172&is=68f1bff2&hm=d777f4281467886d502c38df3639aa62b3c357ab5864e1fda3bc37c82a6025d4&" width="300" alt="Layta"/>

# Layta
<b>Layta</b> is a embeddable modern flexbox-based layout engine and graphical user-interface (GUI) framework for MTA:SA designed to simplify interface development. It provides a comprehensive toolkit for building responsive, visually consistent user interfaces with minimal complexity. <b>Layta</b> streamlines layout management and component design, empowering developers to create modern applications efficiently and elegantly.

## Why?
Since I began developing scripts for MTA:SA, I've created numerous user interfaces using [dx-drawing functions](https://wiki.multitheftauto.com/wiki/Client_Scripting_Functions#Drawing_functions). Throughout that process, I often wished for a system that could handle interface layout automatically—eliminating the need to manually position elements or rely on small helper functions to align them with their parent components. <b>Layta</b> was born from that vision: a desire to bring structure, flexibility, and ease to UI creation, allowing developers to focus on design and functionality rather than layout constraints.

## Getting Started
### Installation
Adding <b>Layta</b> to your project:
1. Download `Layta.lua` from the repository.

2. Place it in your resource folder, for example:

    ```
    my_resource/
    ├── meta.xml
    ├── client.lua
    └── Layta.lua
    ```
  
3. Add it to the resource's meta.xml:

    ```xml
    <meta>
      ...
      <script src="Layta.lua" type="client"/>
    </meta>
    ```

4. Now you can access <b>Layta</b>'s API directly:

    ```lua
    Layta.Node({width = 100, height = 100})
    ```

### Your first UI
Here's how simple it is to get started:
```lua
local ui = Layta.Node({
    flexDirection = "column",
    justifyContent = "center",
    alignItems = "center",
    width = 300,
    height = 150,
    backgroundColor = 0xAA000000,
    borderRadius = 8,
  },
  Layta.Text({ text = "Hello, World!", })
)

-- Add it to the Layta tree
ui:setParent(Layta.tree)
```
That's it — you don't need to handle rendering or layout updates yourself.
<b>Layta</b> automatically renders your UI and manages layout behind the scenes.