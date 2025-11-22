using Toplevel;

public interface ITopLevelManager {

    [CCode (cname = "toplevel_created")]
    public abstract void Toplevel_created(Toplevel.Window *window);

    [CCode (cname = "toplevel_destroyed")]
    public abstract void Toplevel_destroyed(Toplevel.Window *window);

    [CCode (cname = "toplevel_focused")]
    public abstract void toplevel_focused(Toplevel.Window *window);
}

public class TopLevelManager : ITopLevelManager{
    
    [CCode (cname = "toplevel_created")]
    public void Toplevel_created(Toplevel.Window *window){
        print("Toplevel_created");
    }

    [CCode (cname = "toplevel_destroyed")]
    public void Toplevel_destroyed(Toplevel.Window *window){
        print("Toplevel_destroyed");

    }

    [CCode (cname = "toplevel_focused")]
    public void toplevel_focused(Toplevel.Window *window){
        print("Toplevel_focused");
    }
}