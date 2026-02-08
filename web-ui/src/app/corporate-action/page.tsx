"use client";

import { useForm, useFieldArray, SubmitHandler } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { corporateActionSchema, CorporateActionSchema } from "@/schemas/corporateActionSchema";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Label } from "@/components/ui/Label";
import { Button } from "@/components/ui/Button";
import { ErrorMessage } from "@/components/ui/ErrorMessage";
import { useState } from "react";
import axios from "axios";

export default function CorporateActionPage() {
  const [submissionStatus, setSubmissionStatus] = useState<"idle" | "submitting" | "success" | "error">("idle");
  const [serverMessage, setServerMessage] = useState("");

  const {
    register,
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<CorporateActionSchema>({
    resolver: zodResolver(corporateActionSchema),
    defaultValues: {
      corporateActionGeneralInformation: {
        eventType: "DVCA",
        mandatoryVoluntaryEventType: "MAND",
      },
      corporateActionDetails: {
          rateAndPrice: {
              grossDividendRate: undefined
          }
      },
      options: [
        { optionNumber: "001", optionType: "CASH", defaultOption: false }
      ]
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "options",
  });

  const onSubmit: SubmitHandler<CorporateActionSchema> = async (data) => {
    setSubmissionStatus("submitting");
    setServerMessage("");
    try {
      const response = await axios.post("/api/submit", data);

      if (response.status === 202) {
          setSubmissionStatus("success");
          setServerMessage(`Submission received. Your request is being processed. Reference ID: ${response.data.eventId}`);
      } else {
          setSubmissionStatus("success");
          setServerMessage(response.data.message || "Submission successful");
      }
    } catch (error: any) {
      setSubmissionStatus("error");
      setServerMessage(error.response?.data?.message || error.message || "An error occurred");
    }
  };

  return (
    <div className="container mx-auto p-6 max-w-4xl">
      <h1 className="text-3xl font-bold mb-6">Corporate Action Submission</h1>

      {submissionStatus === "success" ? (
          <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded relative" role="alert">
              <strong className="font-bold">Success!</strong>
              <span className="block sm:inline"> {serverMessage}</span>
              <Button className="mt-4 bg-green-600 hover:bg-green-700" onClick={() => setSubmissionStatus("idle")}>Submit Another</Button>
          </div>
      ) : (
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
        {/* General Information */}
        <section className="space-y-4 border p-4 rounded-md shadow-sm">
          <h2 className="text-xl font-semibold">General Information</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="officialCorporateActionEventID">Official Event ID</Label>
              <Input
                id="officialCorporateActionEventID"
                {...register("corporateActionGeneralInformation.officialCorporateActionEventID")}
                className={errors.corporateActionGeneralInformation?.officialCorporateActionEventID ? "border-red-500" : ""}
              />
              <ErrorMessage message={errors.corporateActionGeneralInformation?.officialCorporateActionEventID?.message} />
            </div>

            <div>
              <Label htmlFor="eventType">Event Type</Label>
              <Select
                id="eventType"
                {...register("corporateActionGeneralInformation.eventType")}
              >
                <option value="DVCA">DVCA</option>
                <option value="SPLF">SPLF</option>
                <option value="MRGR">MRGR</option>
                <option value="RHTS">RHTS</option>
              </Select>
              <ErrorMessage message={errors.corporateActionGeneralInformation?.eventType?.message} />
            </div>

            <div>
              <Label htmlFor="mandatoryVoluntaryEventType">Mandatory/Voluntary</Label>
              <Select
                id="mandatoryVoluntaryEventType"
                {...register("corporateActionGeneralInformation.mandatoryVoluntaryEventType")}
              >
                <option value="MAND">MAND</option>
                <option value="VOLU">VOLU</option>
                <option value="CHOS">CHOS</option>
              </Select>
              <ErrorMessage message={errors.corporateActionGeneralInformation?.mandatoryVoluntaryEventType?.message} />
            </div>
          </div>
        </section>

        {/* Underlying Security */}
        <section className="space-y-4 border p-4 rounded-md shadow-sm">
          <h2 className="text-xl font-semibold">Underlying Security</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="isin">ISIN</Label>
              <Input
                id="isin"
                placeholder="XX0000000000"
                {...register("underlyingSecurity.isin")}
                 className={errors.underlyingSecurity?.isin ? "border-red-500" : ""}
              />
              <ErrorMessage message={errors.underlyingSecurity?.isin?.message} />
            </div>
            <div>
              <Label htmlFor="ticker">Ticker (Optional)</Label>
              <Input
                id="ticker"
                {...register("underlyingSecurity.ticker")}
              />
              <ErrorMessage message={errors.underlyingSecurity?.ticker?.message} />
            </div>
          </div>
        </section>

        {/* Corporate Action Details */}
        <section className="space-y-4 border p-4 rounded-md shadow-sm">
          <h2 className="text-xl font-semibold">Details</h2>

          <h3 className="text-lg font-medium">Dates</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="announcementDate">Announcement Date</Label>
              <Input type="date" id="announcementDate" {...register("corporateActionDetails.dates.announcementDate")} />
              <ErrorMessage message={errors.corporateActionDetails?.dates?.announcementDate?.message} />
            </div>
            <div>
              <Label htmlFor="exDate">Ex Date (Optional)</Label>
              <Input type="date" id="exDate" {...register("corporateActionDetails.dates.exDate")} />
              <ErrorMessage message={errors.corporateActionDetails?.dates?.exDate?.message} />
            </div>
            <div>
              <Label htmlFor="recordDate">Record Date</Label>
              <Input type="date" id="recordDate" {...register("corporateActionDetails.dates.recordDate")} />
              <ErrorMessage message={errors.corporateActionDetails?.dates?.recordDate?.message} />
            </div>
             <div>
              <Label htmlFor="paymentDate">Payment Date</Label>
              <Input type="date" id="paymentDate" {...register("corporateActionDetails.dates.paymentDate")} />
              <ErrorMessage message={errors.corporateActionDetails?.dates?.paymentDate?.message} />
            </div>
          </div>

          <h3 className="text-lg font-medium mt-4">Rate and Price (Optional)</h3>
           <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="grossDividendAmount">Gross Dividend Amount</Label>
              <Input
                type="number"
                step="0.01"
                id="grossDividendAmount"
                {...register("corporateActionDetails.rateAndPrice.grossDividendRate.amount")}
              />
              <ErrorMessage message={errors.corporateActionDetails?.rateAndPrice?.grossDividendRate?.amount?.message} />
            </div>
             <div>
              <Label htmlFor="grossDividendCurrency">Currency</Label>
              <Input
                id="grossDividendCurrency"
                maxLength={3}
                placeholder="USD"
                {...register("corporateActionDetails.rateAndPrice.grossDividendRate.currency")}
              />
              <ErrorMessage message={errors.corporateActionDetails?.rateAndPrice?.grossDividendRate?.currency?.message} />
            </div>
          </div>
        </section>

        {/* Options */}
        <section className="space-y-4 border p-4 rounded-md shadow-sm">
          <div className="flex justify-between items-center">
            <h2 className="text-xl font-semibold">Options</h2>
            <Button type="button" onClick={() => append({ optionNumber: "", optionType: "CASH", defaultOption: false })} className="bg-white text-blue-600 border border-blue-600 hover:bg-blue-50">
              Add Option
            </Button>
          </div>

          {fields.map((field, index) => (
            <div key={field.id} className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end border-b pb-4 last:border-0 mt-4">
              <div>
                <Label htmlFor={`options.${index}.optionNumber`}>Option Number</Label>
                <Input
                  {...register(`options.${index}.optionNumber`)}
                   className={errors.options?.[index]?.optionNumber ? "border-red-500" : ""}
                />
                 <ErrorMessage message={errors.options?.[index]?.optionNumber?.message} />
              </div>
              <div>
                <Label htmlFor={`options.${index}.optionType`}>Option Type</Label>
                <Select {...register(`options.${index}.optionType`)}>
                    <option value="CASH">CASH</option>
                    <option value="SECU">SECU</option>
                    <option value="LAPS">LAPS</option>
                </Select>
                 <ErrorMessage message={errors.options?.[index]?.optionType?.message} />
              </div>
              <div className="flex items-center space-x-2 h-10">
                 <input
                    type="checkbox"
                    id={`options.${index}.defaultOption`}
                    {...register(`options.${index}.defaultOption`)}
                    className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                 />
                 <Label htmlFor={`options.${index}.defaultOption`}>Default</Label>
              </div>
              <div>
                  {fields.length > 1 && (
                    <Button type="button" onClick={() => remove(index)} className="bg-red-600 hover:bg-red-700 w-full">
                      Remove
                    </Button>
                  )}
              </div>
            </div>
          ))}
           <ErrorMessage message={errors.options?.root?.message} />
        </section>

        {serverMessage && submissionStatus === "error" && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
                <strong className="font-bold">Error:</strong>
                <span className="block sm:inline"> {serverMessage}</span>
            </div>
        )}

        <div className="flex justify-end">
          <Button type="submit" disabled={submissionStatus === "submitting"}>
            {submissionStatus === "submitting" ? "Submitting..." : "Submit Corporate Action"}
          </Button>
        </div>
      </form>
      )}
    </div>
  );
}
