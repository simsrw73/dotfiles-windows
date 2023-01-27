return {
    "folke/which-key.nvim",
    "folke/neodev.nvim",
    "nvim-lua/plenary.nvim",
    {
        "nvim-tree/nvim-web-devicons",
        config = function()
            require("nvim-web-devicons").setup({ default = true })
        end,
    },
    {
        "petertriho/nvim-scrollbar",
        config = function() require("scrollbar").setup() end
    },
    -- {
    --     'declancm/cinnamon.nvim',
    --     config = function()
    --         require('cinnamon').setup({
    --             extra_keymaps = true,
    --             override_keymaps = true,
    --             max_length = 500,
    --             scroll_limit = -1,
    --         })
    --     end
    -- },
}
