let Hooks = {};

Hooks.AutoDismiss = {
    mounted() {
      // Check if there's an existing flash message and remove it before showing the new one
      let existingFlash = document.querySelector('.flash-message');
      if (existingFlash && existingFlash !== this.el) {
        existingFlash.remove();
      }
  
      setTimeout(() => {
        this.pushEvent("lv:clear-flash", { key: this.el.id.split("-").pop() });
      }, 3000); // Auto-dismiss after 3 seconds
  
      this.el.addEventListener("animationend", () => {
        this.el.remove();
      });
    }
  };

  export default Hooks;