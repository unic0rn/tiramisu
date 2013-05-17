package irc
{
    import mx.controls.dataGridClasses.DataGridItemRenderer;

    public class MultilineHTMLRenderer extends DataGridItemRenderer
    {
        public function MultilineHTMLRenderer()
        {
            super();
        }

        override public function setFocus():void {
            this.setFocus();
        }

        override public function validateProperties():void
        {
            super.validateProperties();
            if (listData)
            {
                htmlText = listData.label;
            }
        }
    }
}
