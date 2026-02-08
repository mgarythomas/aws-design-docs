import { z } from "zod";

export const corporateActionSchema = z.object({
  corporateActionGeneralInformation: z.object({
    officialCorporateActionEventID: z.string().min(1, "Official Corporate Action Event ID is required"),
    eventType: z.enum(["DVCA", "SPLF", "MRGR", "RHTS"], {
      errorMap: () => ({ message: "Please select a valid event type" }),
    }),
    mandatoryVoluntaryEventType: z.enum(["MAND", "VOLU", "CHOS"], {
      errorMap: () => ({ message: "Please select a valid mandatory/voluntary event type" }),
    }),
  }),
  underlyingSecurity: z.object({
    isin: z.string().regex(/^[A-Z]{2}[A-Z0-9]{9}[0-9]$/, "Invalid ISIN format"),
    ticker: z.string().optional(),
  }),
  corporateActionDetails: z.object({
    dates: z.object({
      announcementDate: z.string().refine((val) => !isNaN(Date.parse(val)), "Invalid date"),
      exDate: z.string().optional().refine((val) => !val || !isNaN(Date.parse(val)), "Invalid date"),
      recordDate: z.string().refine((val) => !isNaN(Date.parse(val)), "Invalid date"),
      paymentDate: z.string().refine((val) => !isNaN(Date.parse(val)), "Invalid date"),
    }),
    rateAndPrice: z.object({
      grossDividendRate: z.object({
        amount: z.preprocess(
          (val) => (val === "" ? undefined : Number(val)),
          z.number().positive("Amount must be positive").optional()
        ),
        currency: z.preprocess(
            (val) => (val === "" ? undefined : val),
            z.string().length(3, "Currency must be 3 characters").regex(/^[A-Z]{3}$/, "Invalid currency format").optional()
        ),
      }).optional(),
    }).optional(),
  }),
  options: z.array(
    z.object({
      optionNumber: z.string().min(1, "Option Number is required"),
      optionType: z.enum(["CASH", "SECU", "LAPS"], {
        errorMap: () => ({ message: "Please select a valid option type" }),
      }),
      defaultOption: z.boolean().optional(),
    })
  ).min(1, "At least one option is required"),
});

export type CorporateActionSchema = z.infer<typeof corporateActionSchema>;
